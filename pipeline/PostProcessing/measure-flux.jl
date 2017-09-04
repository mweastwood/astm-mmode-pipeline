function measure_flux(dataset)
    everything = Dict{String, Vector{Float64}}()
    odd = Dict{String, Vector{Float64}}()
    even = Dict{String, Vector{Float64}}()
    for spw = 4:2:18
        @show spw
        @time _everything, _odd, _even = measure_flux(spw, dataset)
        for source in keys(_everything)
            if source in keys(everything)
                push!(everything[source], _everything[source])
                push!(odd[source], _odd[source])
                push!(even[source], _even[source])
            else
                everything[source] = [_everything[source]]
                odd[source] = [_odd[source]]
                even[source] = [_even[source]]
            end
        end
    end

    frequencies = collect(linspace(10e6, 100e6, 201))
    perley = model_flux(frequencies, perley_flux_calibrators())
    scaife = model_flux(frequencies, scaife_flux_calibrators())
    baars  = model_flux(frequencies,  baars_flux_calibrators())

    save(joinpath(dirname(@__FILE__), "..", "..", "workspace", "spectra.jld"),
         "everything", everything, "odd", odd, "even", even,
         "perley", perley, "scaife", scaife, "baars", baars,
         "sources", source_direction)
end

using PyPlot

function measure_flux(spw, dataset)
    dir = getdir(spw)
    @time alm = load(joinpath(dir, "alm-wiener-filtered-$dataset.jld"), "alm")
    @time map = alm2map(alm, 2048)

    @time alm_odd = load(joinpath(dir, "alm-odd-wiener-filtered-$dataset.jld"), "alm")
    @time map_odd = alm2map(alm_odd, 2048)
    @time alm_even = load(joinpath(dir, "alm-even-wiener-filtered-$dataset.jld"), "alm")
    @time map_even = alm2map(alm_even, 2048)

    path = joinpath(dir, "observation-matrix-$dataset.jld")
    @time observation_matrix, cholesky_decomposition, mrange =
        load(path, "blocks", "cholesky", "mrange")
    @time peeling_data = load(joinpath(dir, "peeled-$dataset-visibilities.jld"), "peeling-data")
    @time beam_coeff = load(joinpath(dir, "beam.jld"), "I-coeff")

    @time everything = measure_flux_kernel(spw, dataset, map, alm,
                                     observation_matrix, cholesky_decomposition, mrange,
                                     peeling_data, beam_coeff)
    @time odd = measure_flux_kernel(spw, dataset, map_odd, alm_odd,
                              observation_matrix, cholesky_decomposition, mrange,
                              peeling_data[1:2:end], beam_coeff)
    @time even = measure_flux_kernel(spw, dataset, map_even, alm_even,
                               observation_matrix, cholesky_decomposition, mrange,
                               peeling_data[2:2:end], beam_coeff)
    everything, odd, even
end

function measure_flux_kernel(spw, dataset, map, alm,
                             observation_matrix, cholesky_decomposition, mrange,
                             peeling_data, beam_coeff)
    output = Dict{String, Float64}()
    for source in keys(source_direction)
        output[source] = measure_flux(spw, dataset, source, map, alm,
                                      observation_matrix, cholesky_decomposition, mrange,
                                      peeling_data, beam_coeff)
    end
    output
end

function measure_flux(spw, dataset, source, map, alm,
                      observation_matrix, cholesky_decomposition, mrange, # for measuring flux from the maps
                      peeling_data, beam_coeff) # for measuring flux from the light curves
    direction = source_direction[source]
    if source in ("Cyg A", "Cas A", "Vir A", "Tau A", "Her A", "Hya A", "Per B", "3C 353")
        return get_flux_from_beam(spw, dataset, beam_coeff, peeling_data, direction, source)
    else
        return get_flux_from_map(spw, dataset, map, alm,
                                 observation_matrix, cholesky_decomposition, mrange, direction)
    end
end

function get_flux_from_beam(spw, dataset, beam_coeff, peeling_data, direction, source)
    s = find(removed_source -> removed_source.name == source, peeling_data[1].sources)[1]
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
    flux
end

function get_flux_from_map(spw, dataset, map, alm,
                           observation_matrix, cholesky_decomposition, mrange, direction)
    meta = getmeta(spw, dataset)
    frame = TTCal.reference_frame(meta)
    itrf = measure(frame, direction, dir"ITRF")

    θ = π/2-latitude(itrf)
    ϕ = mod2pi(longitude(itrf))

    psf_alm = Cleaning.getpsf(observation_matrix, cholesky_decomposition,
                              θ, ϕ, lmax(alm), mmax(alm), mrange)

    disc = query_disc(map, θ, ϕ, deg2rad(30/60), inclusive=true)
    annulus = setdiff(query_disc(map, θ, ϕ, deg2rad(3), inclusive=true),
                      query_disc(map, θ, ϕ, deg2rad(1), inclusive=true))
    psf_map = alm2map(psf_alm, 2048)

    numerator = sum(map[pixel] for pixel in disc)
    denominator = sum(psf_map[pixel] for pixel in disc)
    zeropoint = median(collect(map[pixel] for pixel in annulus))*length(disc)
    flux = (numerator-zeropoint)/denominator
    flux
end

const source_direction = Dict("Cyg A"  => Direction(dir"J2000", "19h59m28.35663s", "+40d44m02.0970s"),
                              "Cas A"  => Direction(dir"J2000", "23h23m24s", "58d48m54s"),
                              "Vir A"  => Direction(dir"J2000", "12h30m49.42338s", "+12d23m28.0439s"),
                              "Tau A"  => Direction(dir"J2000", "05h34m31.94s", "+22d00m52.2s"),
                              "Her A"  => Direction(dir"J2000", "16h51m11.4s", "+04d59m20s"),
                              "Hya A"  => Direction(dir"J2000", "09h18m05.651s", "-12d05m43.99s"),
                              "Per B"  => Direction(dir"J2000", "04h37m04.3753s", "+29d40m13.819s"),
                              "3C 353" => Direction(dir"J2000", "17h20m28.147s", "-00d58m47.12s"),
                              "Lyn A"  => Direction(dir"J2000", "08h13m36.05609s", "+48d13m02.6360s"),
                              "3C 48"  => Direction(dir"J2000", "01h37m41.2971s", "+33d09m35.118s"),
                              "3C 147" => Direction(dir"J2000", "05h42m36.2646s", "+49d51m07.083s"),
                              "3C 286" => Direction(dir"J2000", "13h31m08.3s", "+30d30m33s"),
                              "3C 295" => Direction(dir"J2000", "14h11m20.467s", "+52d12m09.52s"),
                              "3C 380" => Direction(dir"J2000", "18h29m31.72483s", "+48d44m46.9515s"))

function model_flux(frequencies, sources)
    output = Dict{String, Vector{Float64}}()
    for (source, spectrum) in sources
        output[source] = [spectrum(ν).I for ν in frequencies]
    end
    output
end

macro perley_spectrum(args...)
    flux = 10^args[1]
    coeff = [args[2:end]...]
    quote
        PowerLaw($flux, 0, 0, 0, 1e9, $coeff)
    end
end

macro scaife_spectrum(args...)
    flux = args[1]
    coeff = [args[2:end]...]
    quote
        PowerLaw($flux, 0, 0, 0, 150e6, $coeff)
    end
end

macro baars_spectrum(args...)
    flux = 10^args[1]
    coeff = [args[2:end]...]
    quote
        PowerLaw($flux, 0, 0, 0, 1e6, $coeff)
    end
end

function perley_flux_calibrators()
    spectra = Dict("3C 48"  => @perley_spectrum(1.3253, -0.7553, -0.1914, +0.0498),
                   "Per B"  => @perley_spectrum(1.8017, -0.7884, -0.1035, -0.0248, +0.0090),
                   "3C 147" => @perley_spectrum(1.4516, -0.6961, -0.2007, +0.0640, -0.0464, +0.0289),
                   "Lyn A"  => @perley_spectrum(1.2872, -0.8530, -0.1534, -0.0200, +0.0201),
                   "Hya A"  => @perley_spectrum(1.7795, -0.9176, -0.0843, -0.0139, +0.0295),
                   "Vir A"  => @perley_spectrum(2.4466, -0.8116, -0.0483),
                   "3C 286" => @perley_spectrum(1.2481, -0.4507, -0.1798, +0.0357),
                   "3C 295" => @perley_spectrum(1.4701, -0.7658, -0.2780, -0.0347, +0.0399),
                   "3C 353" => @perley_spectrum(1.8627, -0.6938, -0.0998, -0.0732),
                   "3C 380" => @perley_spectrum(1.2320, -0.7909, +0.0947, +0.0976, -0.1794, -0.1566),
                   "Cyg A"  => @perley_spectrum(3.3498, -1.0022, -0.2246, +0.0227, +0.0425))
    spectra
end

function scaife_flux_calibrators()
    spectra = Dict("3C 48"  => @scaife_spectrum(64.768, -0.387, -0.420, +0.181),
                   "3C 147" => @scaife_spectrum(66.738, -0.022, -1.012, +0.549),
                   "Lyn A"  => @scaife_spectrum(83.084, -0.699, -0.110),
                   "3C 286" => @scaife_spectrum(27.477, -0.158, +0.032, -0.180),
                   "3C 295" => @scaife_spectrum(97.763, -0.582, -0.298, +0.583, -0.363),
                   "3C 380" => @scaife_spectrum(77.352, -0.767))
    spectra
end

function baars_flux_calibrators()
    spectra = Dict("Cyg A"  => @baars_spectrum(4.695, +0.085, -0.178))
    spectra
end

