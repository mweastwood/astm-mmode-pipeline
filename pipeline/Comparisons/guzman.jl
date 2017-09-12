function compare_with_guzman()
    fits = FITS(joinpath(workspace, "comparison-maps", "wlb45.fits"))
    img = read(fits[1])
    ϕ = linspace(0, 2π, size(img, 1)+1)[1:end-1]
    θ = linspace(0, π, size(img, 2))
    guzman = HealpixMap(Float64, 256)
    N = length(guzman)
    for pix = 1:N
        θ_, ϕ_ = LibHealpix.pix2ang_ring(nside(guzman), pix)
        ϕ_ = mod2pi(π - ϕ_)
        θ_ = π - θ_
        idx = searchsortedlast(ϕ, ϕ_)
        jdx = searchsortedlast(θ, θ_)
        guzman[pix] = img[idx, jdx]
    end

    mask = ones(Bool, N)
    frame = ReferenceFrame()
    sources = [Direction(dir"J2000", "19h59m28s", "+40d44m02s"), # Cyg A
               Direction(dir"J2000", "23h23m24s", "+58d48m54s"), # Cas A
               Direction(dir"J2000", "12h30m49s", "+12d23m28s"), # Vir A
               Direction(dir"J2000", "05h34m32s", "+22d00m52s")] # Tau A
    for pix = 1:length(guzman)
        θ, ϕ = LibHealpix.pix2ang_ring(nside(guzman), pix)
        galactic = Direction(dir"GALACTIC", ϕ*radians, (π/2-θ)*radians)
        j2000 = measure(frame, galactic, dir"J2000")
        ra = longitude(j2000)
        dec = latitude(j2000)
        if dec < deg2rad(-30)
            mask[pix] = false
        elseif dec > deg2rad(+65)
            mask[pix] = false
        end
        for source in sources
            if acosd(j2000.x*source.x + j2000.y*source.y + j2000.z*source.z) < 10
                mask[pix] = false
            end
        end
    end

    # Subtract sources from the Guzman maps
    function gaussian(x, y, A, σx, σy, θ)
        a = cos(θ)^2/(2σx^2) + sin(θ)^2/(2σy^2)
        b = -sin(2θ)/(4σx^2) + sin(2θ)/(4σy^2)
        c = sin(θ)^2/(2σx^2) + cos(θ)^2/(2σy^2)
        A*exp(-(a*x^2 + 2b*x*y + c*y^2))
    end
    function residual(map, disc, xlist, ylist, params)
        output = 0.0
        for (pixel, x, y) in zip(disc, xlist, ylist)
            g = gaussian(x, y, params[1], params[2], params[3], params[4])
            output += abs2(map[pixel] - g - params[5])
        end
        output
    end
    function remove(disc, xlist, ylist, params)
        for (pixel, x, y) in zip(disc, xlist, ylist)
            g = gaussian(x, y, params[1], params[2], params[3], params[4])
            guzman[pixel] -= g
        end
    end
    for source in sources
        direction = measure(frame, source, dir"GALACTIC")
        θ = π/2-latitude(direction)
        ϕ = longitude(direction)
        vec = LibHealpix.ang2vec(θ, ϕ)
        rhat = vec / norm(vec)
        north = [0, 0, 1]
        north = north - dot(rhat, north)*rhat
        north = north / norm(north)
        east = cross(north, rhat)
        disc = LibHealpix.query_disc(guzman, θ, ϕ, deg2rad(10), inclusive=true)
        x = Float64[]
        y = Float64[]
        for pix in disc
            myvec = LibHealpix.pix2vec_ring(nside(guzman), Int(pix))
            push!(x, asind(dot(myvec, east)))
            push!(y, asind(dot(myvec, north)))
        end

        opt = Opt(:LN_SBPLX, 5)
        ftol_rel!(opt, 1e-10)
        min_objective!(opt, (params, _)->residual(guzman, disc, x, y, params))
        println("starting")
        lower_bounds!(opt, [1, 1, 1, -π/2, 1])
        upper_bounds!(opt, [1e6, 10, 10, +π/2, 1e6])
        @time minf, params, ret = optimize(opt, [1, 5, 5, 0, 1])
        @show minf, params, ret
        remove(disc, x, y, params)
    end

    # Interpolate the LWA maps to 45 MHz
    spw = 6
    dir = Pipeline.Common.getdir(spw)
    ν6 = Pipeline.Common.getfreq(spw)
    lwa6 = readhealpix(joinpath(dir, "map-wiener-filtered-rainy-2048-galactic.fits"))

    spw = 8
    dir = Pipeline.Common.getdir(spw)
    ν8 = Pipeline.Common.getfreq(spw)
    lwa8 = readhealpix(joinpath(dir, "map-wiener-filtered-rainy-2048-galactic.fits"))

    ν = 45e6
    w6 = 1 - (ν - ν6)/(ν8 - ν6)
    w8 = 1 - w6

    lwa6 = lwa6 * (BPJSpec.Jy * (BPJSpec.c/ν)^2 / (2*BPJSpec.k))
    lwa8 = lwa8 * (BPJSpec.Jy * (BPJSpec.c/ν)^2 / (2*BPJSpec.k))
    lwa = w6*lwa6 + w8*lwa8
    @time lwa = smooth(lwa, 5, nside(guzman))

    # Filter the Guzman map in the same way the LWA map is filtered
    alm = map2alm(Pipeline.MModes.rotate_from_galactic(6, "rainy", guzman), 500, 500)
    @show alm[0, 0]
    Pipeline.MModes.apply_wiener_filter!(alm, 0:0)
    filtered_guzman = Pipeline.MModes.rotate_to_galactic(6, "rainy", alm2map(alm, nside(guzman)))

    lwa_pixels = [lwa.pixels[idx] for idx = 1:N if mask[idx]]
    guzman_pixels = [guzman.pixels[idx] for idx = 1:N if mask[idx]]
    monopole = mean(guzman_pixels)

    δ = HealpixMap(Float64, nside(guzman))
    for idx = 1:N
        if mask[idx]
            δ[idx] = (lwa[idx] - filtered_guzman[idx])/guzman[idx]
        end
    end

    save("comparison-with-guzman.jld",
         "guzman", guzman.pixels, "filtered_guzman", filtered_guzman.pixels,
         "lwa", lwa.pixels, "difference", δ.pixels)
end

