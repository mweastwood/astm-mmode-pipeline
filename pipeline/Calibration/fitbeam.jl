function fitbeam(spw, dataset, target)
    dir = getdir(spw)
    peeling_data = load(joinpath(dir, "$target-$dataset-visibilities.jld"), "peeling-data")
    _fitbeam(spw, dataset, peeling_data)
end

function _fitbeam(spw, dataset, peeling_data)
    meta = getmeta(spw, dataset)
    frame = TTCal.reference_frame(meta)
    peeling_data = filter_out_the_sun(peeling_data)

    N = length(peeling_data[1].sources)
    names = [source.name for source in peeling_data[1].sources]
    I, Q, l, m, σ = prepare_data(frame, peeling_data)
    ρ = hypot.(l, m)
    θ = atan2.(l, m)

    opt = Opt(:LN_COBYLA, N+15)
    min_objective!(opt, (x, g) -> chi_squared(x, I, Q, ρ, θ, σ))
    equality_constraint!(opt, (x, g) -> normalization(x, I))
    ftol_rel!(opt, 1e-4)

    x0 = [fill(10000.0, N); 1.0; fill(0.0, 14)]
    minf, x, ret = optimize(opt, x0)

    fluxes = x[1:N]
    coeff_I = x[N+1:N+9]
    coeff_Q = x[N+10:N+15]
    output_params(spw, names, fluxes, coeff_I, coeff_Q)
    output_healpix(spw, dataset, coeff_I)

    #figure(1); clf()
    #img = zeros(501, 501)
    #for (idx, l_) in enumerate(linspace(-1, 1, size(img, 1)))
    #    for (jdx, m_) in enumerate(linspace(-1, 1, size(img, 2)))
    #        ρ_ = hypot(l_, m_)
    #        θ_ = atan2(l_, m_)
    #        ρ_ > 1 && continue
    #        img[jdx, idx] = (params[1]*TTCal.zernike(0, 0, ρ_, θ_)
    #                        + params[2]*TTCal.zernike(2, 0, ρ_, θ_)
    #                        + params[3]*TTCal.zernike(4, 0, ρ_, θ_)
    #                        + params[4]*TTCal.zernike(4, 4, ρ_, θ_)
    #                        + params[5]*TTCal.zernike(6, 0, ρ_, θ_)
    #                        + params[6]*TTCal.zernike(6, 4, ρ_, θ_)
    #                        + params[7]*TTCal.zernike(8, 0, ρ_, θ_)
    #                        + params[8]*TTCal.zernike(8, 4, ρ_, θ_)
    #                        + params[9]*TTCal.zernike(8, 8, ρ_, θ_))
    #    end
    #end
    #circle = plt[:Circle]((0, 0), 1, alpha=0)
    #gca()[:add_patch](circle)
    #imshow(img, extent=(-1, 1, -1, 1), interpolation="nearest", vmin=0, vmax=1,
    #       cmap=get_cmap("magma"), clip_path=circle)
    #gca()[:set_aspect]("equal")
    #colorbar()
    #for s = 1:N
    #    scatter(l[s], m[s], c=(I[s]/fluxes[s]), vmin=0, vmax=1, cmap=get_cmap("magma"))
    #end
    #xlim(-1, 1)
    #ylim(-1, 1)

    #for s = 1:N
    #    figure(s); clf()
    #    plot(I[s], "k.")
    #    expected = Float64[]
    #    for (l_, m_) in zip(l[s], m[s])
    #        ρ_ = hypot(l_, m_)
    #        θ_ = atan2(l_, m_)
    #        beam = (params[1]*TTCal.zernike(0, 0, ρ_, θ_)
    #                    + params[2]*TTCal.zernike(2, 0, ρ_, θ_)
    #                    + params[3]*TTCal.zernike(4, 0, ρ_, θ_)
    #                    + params[4]*TTCal.zernike(4, 4, ρ_, θ_)
    #                    + params[5]*TTCal.zernike(6, 0, ρ_, θ_)
    #                    + params[6]*TTCal.zernike(6, 4, ρ_, θ_)
    #                    + params[7]*TTCal.zernike(8, 0, ρ_, θ_)
    #                    + params[8]*TTCal.zernike(8, 4, ρ_, θ_)
    #                    + params[9]*TTCal.zernike(8, 8, ρ_, θ_))
    #        push!(expected, beam*fluxes[s])
    #    end
    #    plot(expected, "r.")
    #    title(names[s])
    #end
end

function filter_out_the_sun(peeling_data)
    peeling_data = deepcopy(peeling_data)
    for idx = 1:length(peeling_data)
        data = peeling_data[idx]
        names = [source.name for source in data.sources]
        sun = first(find(names .== "Sun"))
        deleteat!(data.sources, sun)
        deleteat!(data.I, sun)
        deleteat!(data.Q, sun)
        deleteat!(data.directions, sun)
    end
    peeling_data
end

function prepare_data(frame, peeling_data)
    Ntime = length(peeling_data)
    Nsource = length(peeling_data[1].sources)
    output_I = Vector{Float64}[]
    output_Q = Vector{Float64}[]
    output_l = Vector{Float64}[]
    output_m = Vector{Float64}[]
    output_σ = Vector{Float64}[]
    for s = 1:Nsource
        I = Float64[]
        Q = Float64[]
        l = Float64[]
        m = Float64[]
        σ = Float64[]
        for idx = 1:Ntime
            data = peeling_data[idx]
            data.I[s] == data.Q[s] == 0 && continue
            push!(I, data.I[s])
            push!(Q, data.Q[s])

            t = data.time
            set!(frame, Epoch(epoch"UTC", t*seconds))
            azel = measure(frame, data.directions[s], dir"AZEL")
            az = longitude(azel)
            el =  latitude(azel)
            push!(l, sin(az) * cos(el))
            push!(m, cos(az) * cos(el))
        end
        for idx = 1:length(I)
            range = max(1, idx-50):min(length(I), idx+50)
            push!(σ, std(I[range]))
        end
        push!(output_I, I)
        push!(output_Q, Q)
        push!(output_l, l)
        push!(output_m, m)
        push!(output_σ, σ)
    end
    output_I, output_Q, output_l, output_m, output_σ
end

function chi_squared(x, I, Q, ρ, θ, σ)
    Nsources = length(I)
    fluxes = x[1:Nsources]
    params = x[Nsources+1:end]
    χ2 = 0.0
    normalization = 0.0
    for s = 1:Nsources
        my_I = I[s]
        my_Q = Q[s]
        my_ρ = ρ[s]
        my_θ = θ[s]
        my_σ = σ[s]
        Ntime = length(my_I)
        for idx = 1:Ntime
            stokes_I_beam = (params[1]*TTCal.zernike(0, 0, my_ρ[idx], my_θ[idx])
                            + params[2]*TTCal.zernike(2, 0, my_ρ[idx], my_θ[idx])
                            + params[3]*TTCal.zernike(4, 0, my_ρ[idx], my_θ[idx])
                            + params[4]*TTCal.zernike(4, 4, my_ρ[idx], my_θ[idx])
                            + params[5]*TTCal.zernike(6, 0, my_ρ[idx], my_θ[idx])
                            + params[6]*TTCal.zernike(6, 4, my_ρ[idx], my_θ[idx])
                            + params[7]*TTCal.zernike(8, 0, my_ρ[idx], my_θ[idx])
                            + params[8]*TTCal.zernike(8, 4, my_ρ[idx], my_θ[idx])
                            + params[9]*TTCal.zernike(8, 8, my_ρ[idx], my_θ[idx]))
            stokes_Q_beam = (params[10]*TTCal.zernike(2, 2, my_ρ[idx], my_θ[idx])
                            + params[11]*TTCal.zernike(4, 2, my_ρ[idx], my_θ[idx])
                            + params[12]*TTCal.zernike(6, 2, my_ρ[idx], my_θ[idx])
                            + params[13]*TTCal.zernike(6, 6, my_ρ[idx], my_θ[idx])
                            + params[14]*TTCal.zernike(8, 2, my_ρ[idx], my_θ[idx])
                            + params[15]*TTCal.zernike(8, 6, my_ρ[idx], my_θ[idx]))
            temp  = abs2(my_I[idx] - fluxes[s]*stokes_I_beam)
            temp += abs2(my_Q[idx] - fluxes[s]*stokes_Q_beam)
            χ2 += temp
            normalization += 1
        end
    end
    χ2 /= normalization
    χ2
end

function normalization(x, I)
    N = length(I)
    params = x[N+1:end]
    beam = (params[1]*TTCal.zernike(0, 0, 0, 0)
                + params[2]*TTCal.zernike(2, 0, 0, 0)
                + params[3]*TTCal.zernike(4, 0, 0, 0)
                + params[4]*TTCal.zernike(4, 4, 0, 0)
                + params[5]*TTCal.zernike(6, 0, 0, 0)
                + params[6]*TTCal.zernike(6, 4, 0, 0)
                + params[7]*TTCal.zernike(8, 0, 0, 0)
                + params[8]*TTCal.zernike(8, 4, 0, 0)
                + params[9]*TTCal.zernike(8, 8, 0, 0))
    beam - 1
end

function output_params(spw, names, fluxes, coeff_I, coeff_Q)
    dir = getdir(spw)

    # image the results
    img1 = zeros(512, 512)
    img2 = zeros(512, 512)
    l = linspace(-1, 1, 512)
    m = linspace(-1, 1, 512)
    for j = 1:length(m), i = 1:length(l)
        ρ = hypot(l[i], m[j])
        ρ ≥ 1 && continue
        θ = atan2(l[i], m[j])
        stokes_I_beam = (coeff_I[1]*TTCal.zernike(0, 0, ρ, θ)
                        + coeff_I[2]*TTCal.zernike(2, 0, ρ, θ)
                        + coeff_I[3]*TTCal.zernike(4, 0, ρ, θ)
                        + coeff_I[4]*TTCal.zernike(4, 4, ρ, θ)
                        + coeff_I[5]*TTCal.zernike(6, 0, ρ, θ)
                        + coeff_I[6]*TTCal.zernike(6, 4, ρ, θ)
                        + coeff_I[7]*TTCal.zernike(8, 0, ρ, θ)
                        + coeff_I[8]*TTCal.zernike(8, 4, ρ, θ)
                        + coeff_I[9]*TTCal.zernike(8, 8, ρ, θ))
        stokes_Q_beam = (coeff_Q[1]*TTCal.zernike(2, 2, ρ, θ)
                        + coeff_Q[2]*TTCal.zernike(4, 2, ρ, θ)
                        + coeff_Q[3]*TTCal.zernike(6, 2, ρ, θ)
                        + coeff_Q[4]*TTCal.zernike(6, 6, ρ, θ)
                        + coeff_Q[5]*TTCal.zernike(8, 2, ρ, θ)
                        + coeff_Q[6]*TTCal.zernike(8, 6, ρ, θ))
        img1[i,j] = stokes_I_beam
        img2[i,j] = stokes_Q_beam
    end

    save(joinpath(dir, "beam.jld"), "sources", names, "fluxes", fluxes,
                                    "I-coeff", coeff_I, "Q-coeff", coeff_Q,
                                    "I-image", img1, "Q-image", img2)
end

function output_healpix(spw, dataset, coeff)
    meta = getmeta(spw)
    frame = TTCal.reference_frame(meta)
    position = measure(frame, TTCal.position(meta), pos"ITRF")
    zenith = [position.x, position.y, position.z]
    zenith = zenith / norm(zenith)
    north  = [0.0, 0.0, 1.0]
    north  = north - dot(north, zenith)*zenith
    north  = north / norm(north)
    east   = cross(north, zenith)
    nside = 1024
    map = HealpixMap(Float64, nside)
    for pix = 1:length(map)
        vec = LibHealpix.pix2vec_ring(nside, pix)
        el = π/2 - acos(dot(vec, zenith))
        x  = dot(vec, east)
        y  = dot(vec, north)
        az = atan2(x, y)
        ρ = cos(el)
        θ = az
        threshold = 0
        if el < threshold
            map[pix] = 0
        else
            map[pix] = (coeff[1]*TTCal.zernike(0, 0, ρ, θ)
                        + coeff[2]*TTCal.zernike(2, 0, ρ, θ)
                        + coeff[3]*TTCal.zernike(4, 0, ρ, θ)
                        + coeff[4]*TTCal.zernike(4, 4, ρ, θ)
                        + coeff[5]*TTCal.zernike(6, 0, ρ, θ)
                        + coeff[6]*TTCal.zernike(6, 4, ρ, θ)
                        + coeff[7]*TTCal.zernike(8, 0, ρ, θ)
                        + coeff[8]*TTCal.zernike(8, 4, ρ, θ)
                        + coeff[9]*TTCal.zernike(8, 8, ρ, θ))
        end
    end

    output = joinpath(getdir(spw), "beam.fits")
    writehealpix(output, map, replace=true)

    nothing
end

function is_this_zernike_polynomial_allowed_for_stokes_I(n, m)
    # roll 100 random points and see if it has the right symmetries
    for i = 1:100
        ρ = rand()
        θ = 2π*rand()

        z1 = TTCal.zernike(n, m, ρ, θ)
        z2 = TTCal.zernike(n, m, ρ, θ+π/2)
        z3 = TTCal.zernike(n, m, ρ, θ+π)
        z4 = TTCal.zernike(n, m, ρ, θ+3π/2)
        z5 = TTCal.zernike(n, m, ρ, -θ)
        z6 = TTCal.zernike(n, m, ρ, -θ+π/2)
        z7 = TTCal.zernike(n, m, ρ, -θ+π)
        z8 = TTCal.zernike(n, m, ρ, -θ+3π/2)

        if !(z1 ≈ z2 ≈ z3 ≈ z4 ≈ z5 ≈ z6 ≈ z7 ≈ z8)
            return false
        end
    end
    true
end

function is_this_zernike_polynomial_allowed_for_stokes_Q(n, m)
    # roll 100 random points and see if it has the right symmetries
    for i = 1:100
        ρ = rand()
        θ = 2π*rand()

        z1 = TTCal.zernike(n, m, ρ, θ)
        z2 = TTCal.zernike(n, m, ρ, θ+π/2)
        z3 = TTCal.zernike(n, m, ρ, θ+π)
        z4 = TTCal.zernike(n, m, ρ, θ+3π/2)
        z5 = TTCal.zernike(n, m, ρ, -θ)
        z6 = TTCal.zernike(n, m, ρ, -θ+π/2)
        z7 = TTCal.zernike(n, m, ρ, -θ+π)
        z8 = TTCal.zernike(n, m, ρ, -θ+3π/2)

        if !(z1 ≈ -z2 ≈ z3 ≈ -z4 ≈ z5 ≈ -z6 ≈ z7 ≈ -z8)
            return false
        end
    end
    true
end

