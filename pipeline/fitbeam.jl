function fitbeam(spw)
    Lumberjack.info("Fitting the beam at spectral window $spw")
    dir = getdir(spw)
    raw_I, raw_Q, az, el = load(joinpath(dir, "source-information.jld"), "I", "Q", "az", "el")
    names = UTF8String[]
    I = Vector{Float64}[]
    Q = Vector{Float64}[]
    ρ = Vector{Float64}[]
    θ = Vector{Float64}[]
    for source in keys(raw_I)
        source == "Sun" && continue
        my_I = raw_I[source]::Vector{Float64}
        my_Q = raw_Q[source]::Vector{Float64}
        my_az = az[source]::Vector{Float64}
        my_el = el[source]::Vector{Float64}
        l = sin(my_az).*cos(my_el)
        m = cos(my_az).*cos(my_el)
        # weed out some of the garbage
        keep = fill(true, length(my_I))
        for idx = 1:length(my_I)
            if idx != 1
                if isnan(my_I[idx]) || isnan(my_Q[idx])
                    keep[idx] = false
                elseif abs(my_I[idx] - my_I[idx-1]) > 0.2min(abs(my_I[idx]), abs(my_I[idx-1]))
                    keep[idx] = false
                    keep[idx-1] = false
                elseif hypot(l[idx] - l[idx-1], m[idx] - m[idx-1]) > 0.1
                    keep[idx] = false
                    keep[idx-1] = false
                end
            end
        end
        l = l[keep]
        m = m[keep]
        my_I = my_I[keep]
        my_Q = my_Q[keep]
        my_ρ = hypot(l, m)
        my_θ = atan2(l, m)
        push!(I, my_I)
        push!(Q, my_Q)
        push!(ρ, my_ρ)
        push!(θ, my_θ)
        push!(names, source)
    end
    N = length(I)

    function chi_squared(x, g)
        fluxes = x[1:N]
        params = x[N+1:end]
        χ2 = 0.0
        for idx = 1:N
            my_I = I[idx]
            my_Q = Q[idx]
            my_ρ = ρ[idx]
            my_θ = θ[idx]
            for jdx = 1:length(my_I)
                stokes_I_beam = (params[1]*TTCal.zernike(0, 0, my_ρ[jdx], my_θ[jdx])
                                + params[2]*TTCal.zernike(2, 0, my_ρ[jdx], my_θ[jdx])
                                + params[3]*TTCal.zernike(4, 0, my_ρ[jdx], my_θ[jdx])
                                + params[4]*TTCal.zernike(4, 4, my_ρ[jdx], my_θ[jdx])
                                + params[5]*TTCal.zernike(6, 0, my_ρ[jdx], my_θ[jdx])
                                + params[6]*TTCal.zernike(6, 4, my_ρ[jdx], my_θ[jdx])
                                + params[7]*TTCal.zernike(8, 0, my_ρ[jdx], my_θ[jdx])
                                + params[8]*TTCal.zernike(8, 4, my_ρ[jdx], my_θ[jdx])
                                + params[9]*TTCal.zernike(8, 8, my_ρ[jdx], my_θ[jdx]))
                stokes_Q_beam = (params[10]*TTCal.zernike(2, 2, my_ρ[jdx], my_θ[jdx])
                                + params[11]*TTCal.zernike(4, 2, my_ρ[jdx], my_θ[jdx])
                                + params[12]*TTCal.zernike(6, 2, my_ρ[jdx], my_θ[jdx])
                                + params[13]*TTCal.zernike(6, 6, my_ρ[jdx], my_θ[jdx])
                                + params[14]*TTCal.zernike(8, 2, my_ρ[jdx], my_θ[jdx])
                                + params[15]*TTCal.zernike(8, 6, my_ρ[jdx], my_θ[jdx]))
                χ2 += abs2(my_I[jdx] - fluxes[idx]*stokes_I_beam) + abs2(my_Q[jdx] - fluxes[idx]*stokes_Q_beam)
            end
        end
        Lumberjack.debug("params = $x")
        χ2
    end

    function normalization(x, g)
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

    Lumberjack.info("Starting optimization.")
    opt = Opt(:LN_COBYLA, N+15)
    min_objective!(opt, chi_squared)
    equality_constraint!(opt, normalization)
    ftol_rel!(opt, 1e-4)

    x0 = [fill(10000.0, N); 1.0; fill(0.0, 14)]
    #x0 = [2144.191533687852,1689.7825612220843,941.2355667514099,677.9271199554415,17085.132880250636,18848.425606341832,426.5897732606499,0.5438737422971801,-0.45184258604991584,-0.01674142678893857,-0.04036363639937381,-0.032644353993999724,0.047008431536809975,-0.01161849690351406,-0.0008122133788586208,-0.016239247375396112,-0.10410871718009305,0.12315052775867515,9.34730233532972e-5,-0.006081616593686574,-0.001440312783256139,0.002597285340770812]
    #x0 = [3619.170800138876,2108.7176828655256,1795.9873815260642,1282.0350681694254,28010.82128649241,27549.278266050158,692.8744545700363,0.5249880062190876,-0.4820942107600547,-0.011269308262222052,-0.0463246012905888,-0.007124905630025072,0.056935795248331963,-0.002937814346945719,-0.00014347363545219214,-0.009984798916080541,-0.0918613683795595,0.10204059303344623,0.0002913640698440229,-0.00828507588501658,-0.00220464859224213,0.0059441134296844755]
    minf, x, ret = optimize(opt, x0)
    Lumberjack.debug("ret = $ret")
    Lumberjack.info("Optimization completed.")

    source_fluxes = x[1:N]
    coeff_I = x[N+1:N+9]
    coeff_Q = x[N+10:N+15]

    output_params(spw, names, source_fluxes, coeff_I, coeff_Q)
    output_healpix(spw, coeff_I)

end

function output_params(spw, names, source_fluxes, coeff_I, coeff_Q)
    dir = getdir(spw)

    # image the results
    img1 = zeros(1000, 1000)
    img2 = zeros(1000, 1000)
    l = linspace(-1, 1, 1000)
    m = linspace(-1, 1, 1000)
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

    save(joinpath(dir, "beam.jld"), "sources", names, "fluxes", source_fluxes,
                                    "I-coeff", coeff_I, "Q-coeff", coeff_Q,
                                    "I-image", img1, "Q-image", img2)
end

function output_healpix(spw, coeff)
    mountain_az, mountain_el = load(joinpath(workspace, "mountain-elevation.jld"), "az", "el")
    mountain_az = deg2rad(mountain_az)
    mountain_el = deg2rad(mountain_el)
    mountain = interpolate((mountain_az,), mountain_el, Gridded(Linear()))

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
        # check to see where the horizon is at this azimuth
        threshold = mountain[mod2pi(az)]
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

    output = joinpath(getdir(spw), "beam-map.fits")
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

