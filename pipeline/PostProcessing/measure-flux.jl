using PyPlot

function measure_flux(dataset)
    # compare fluxes measured in the two different ways
    dir = getdir(4)
    @time cyga_map = readhealpix(joinpath(dir, "map-cyga-restored-interpolated-rainy-2048-itrf.fits"))
    @time cyga_alm = load(joinpath(dir, "alm-cyga-restored-interpolated-rainy.jld"), "alm")
    @time psf = load(joinpath(dir, "psf", "psf.jld"), "psf")
    ##@time peeling_data = load(joinpath(dir, "peeled-rainy-visibilities.jld"), "peeling-data")
    ##@time beam_coeff = load(joinpath(dir, "beam.jld"), "I-coeff")

    ##sources = Dict("Cyg A" => Direction(dir"J2000", "19h59m28.35663s", "+40d44m02.0970s"),
    ##                              "Cas A" => Direction(dir"J2000", "23h23m24.000s", "+58d48m54.00s"))
    direction = Direction(dir"J2000", "19h59m28.35663s", "+40d44m02.0970s")
    #get_flux_from_beam(4, dataset, beam_coeff, peeling_data, direction, 1)
    simulated_alm = load("checkpoint3.jld", "alm")
    simulated_map = alm2map(simulated_alm, 2048)
    #get_flux_from_map(4, dataset, cyga_alm, cyga_map, psf, direction)
    get_flux_from_map(4, dataset, simulated_alm, simulated_map, psf, direction)
    #simulate(4, dataset, direction)
end


function get_flux_from_beam(spw, dataset, beam_coeff, peeling_data, direction, s)
    N = length(peeling_data)
    t = zeros(N)
    l = zeros(N)
    m = zeros(N)
    I = zeros(N)
    beam = zeros(N)
    flags = zeros(Bool, N)

    meta = getmeta(spw, dataset)
    frame = TTCal.reference_frame(meta)

    for idx = 1:N
        # extract the measured flux
        data = peeling_data[idx]
        set!(frame, Epoch(epoch"UTC", data.time*seconds))

        t[idx] = data.time
        if data.I[s] == data.Q[s] == 0
            flags[idx] = true
        end
        azel = measure(frame, direction, dir"AZEL")
        az = longitude(azel)
        el =  latitude(azel)
        el < 0 && continue
        l[idx] = sin(az) * cos(el)
        m[idx] = cos(az) * cos(el)
        I[idx] = data.I[s]

        # compute the beam amplitude
        ρ = hypot(l[idx], m[idx])
        θ = atan2(l[idx], m[idx])
        beam[idx] = (beam_coeff[1]*TTCal.zernike(0, 0, ρ, θ)
                    + beam_coeff[2]*TTCal.zernike(2, 0, ρ, θ)
                    + beam_coeff[3]*TTCal.zernike(4, 0, ρ, θ)
                    + beam_coeff[4]*TTCal.zernike(4, 4, ρ, θ)
                    + beam_coeff[5]*TTCal.zernike(6, 0, ρ, θ)
                    + beam_coeff[6]*TTCal.zernike(6, 4, ρ, θ)
                    + beam_coeff[7]*TTCal.zernike(8, 0, ρ, θ)
                    + beam_coeff[8]*TTCal.zernike(8, 4, ρ, θ)
                    + beam_coeff[9]*TTCal.zernike(8, 8, ρ, θ))
    end

    _beam = beam[!flags]
    _I = I[!flags]
    flux = dot(_I, _beam)/dot(_beam, _beam)
    @show flux

    figure(1); clf()
    plot(t[!flags], I[!flags], "k-")
    plot(t, beam*flux, "r-")
end

function get_flux_from_map(spw, dataset, alm, map, psf, direction)
    meta = getmeta(spw, dataset)
    frame = TTCal.reference_frame(meta)
    itrf = measure(frame, direction, dir"ITRF")

    θ = π/2-latitude(itrf)
    ϕ = mod2pi(longitude(itrf))

    path = joinpath(getdir(spw), "observation-matrix-$dataset.jld")
    lmax, mmax, mrange = load(path, "lmax", "mmax", "mrange")
    @time observation_matrix, cholesky_decomposition = load(path, "blocks", "cholesky")
    @time psf_alm = Cleaning.getpsf(observation_matrix, cholesky_decomposition, θ, ϕ, lmax, mmax, mrange)

    disc = query_disc(map, θ, ϕ, deg2rad(30/60), inclusive=true)
    psf_map = alm2map(psf_alm, 2048)

    @show sum(psf_map[pixel] for pixel in disc)
    @show sum(map[pixel] for pixel in disc)


    #@show length(disc)
    #pixel = disc[indmax(map[pixel] for pixel in disc)]
    #ring = searchsortedlast(psf.pixels, pixel)

    #@show pixel ring map[pixel] psf.amplitudes[ring]
    #@show map[pixel]/psf.amplitudes[ring]


    ##@show dot(alm.alm, psf_alm.alm) dot(psf_alm.alm, psf_alm.alm)
    #psf_alm
end

function simulate(spw, dataset, direction)
    dir = getdir(spw)
    meta = getmeta(spw, dataset)
    times, flags = load(joinpath(dir, "peeled-rainy-visibilities.jld"), "times", "flags")
    beam_coeff = load(joinpath(dir, "beam.jld"), "I-coeff")
    beam = ZernikeBeam(beam_coeff)
    data = zeros(Complex128, 2, Nbase(meta), length(times))
    @time peeling_data = load(joinpath(dir, "peeled-rainy-visibilities.jld"), "peeling-data")
    simulate!(data, flags, meta, beam, times, direction, peeling_data)
    save("checkpoint1.jld", "data", data)
    #data = load("checkpoint1.jld", "data")
    folded_data, folded_flags = MModes._fold(spw, data, flags, dataset, "test")
    mmodes, mmode_flags = MModes.getmmodes_internal(folded_data, folded_flags)
    save("checkpoint2.jld", "mmodes", mmodes, "flags", mmode_flags)
    #mmodes, mmode_flags = load("checkpoint2.jld", "mmodes", "flags")
    alm = MModes._getalm(4, mmodes, mmode_flags)
    save("checkpoint3.jld", "alm", alm)
end

function simulate!(data, flags, meta, beam, times, direction, peeling_data)
    #source = PointSource("Test", direction, PowerLaw(1, 0, 0, 0, 74e6, [0.0]))
    meta.channels = meta.channels[55:55]
    meta.phase_center = Direction(dir"AZEL", 0degrees, 90degrees)

    Ntime = length(times)
    prg = Progress(Ntime)
    for integration = 1:Ntime
        source = PointSource("Test", peeling_data[integration].directions[1], PowerLaw(1, 0, 0, 0, 74e6, [0.0]))
        meta.time = Epoch(epoch"UTC", times[integration]*seconds)
        !all(flags[:, integration]) || @goto skip
        visibilities = genvis(meta, beam, source)
        xx = getfield.(visibilities.data[:, 1], 1)
        yy = getfield.(visibilities.data[:, 1], 4)
        data[1, :, integration] = xx
        data[2, :, integration] = xx
        @label skip
        next!(prg)
    end
end

