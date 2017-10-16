function lwa1()
    lwa1_original = Vector{Float64}[]
    lwa1 = Vector{Float64}[]
    ovro_lwa = Vector{Float64}[]
    masks = Vector{Bool}[]
    for (ν, filename, resolution) in ((38e6, "healpix-all-sky-rav-wsclean-map-38.fits", 4.3),
                                      (40e6, "healpix-all-sky-rav-wsclean-map-40.fits", 4.1),
                                      (45e6, "healpix-all-sky-rav-wsclean-map-45.fits", 3.6),
                                      (50e6, "healpix-all-sky-rav-wsclean-map-50.fits", 3.3),
                                      (60e6, "healpix-all-sky-rav-wsclean-map-60.fits", 2.7),
                                      (70e6, "healpix-all-sky-rav-wsclean-map-70.fits", 2.3))
        @time result = lwa1_comparison(ν, filename, resolution)
        push!(lwa1_original, result[1])
        push!(lwa1, result[2])
        push!(ovro_lwa, result[3])
        push!(masks, result[4])
    end
    save("lwa1-comparison.jld", "lwa1-original", lwa1_original, "lwa1", lwa1, "ovro", ovro_lwa,
         "masks", masks)
end

function lwa1_comparison(ν, filename, resolution)
    lwa1 = readhealpix(joinpath(workspace, "comparison-maps", filename))
    lwa1.pixels[lwa1.pixels .== -1.6375f30] = 0
    N = length(lwa1)

    mask = ones(Bool, N)
    frame = ReferenceFrame()
    sources = [Direction(dir"J2000", "19h59m28s", "+40d44m02s"), # Cyg A
               Direction(dir"J2000", "23h23m24s", "+58d48m54s"), # Cas A
               Direction(dir"J2000", "12h30m49s", "+12d23m28s"), # Vir A
               Direction(dir"J2000", "05h34m32s", "+22d00m52s")] # Tau A
    for pix = 1:N
        θ, ϕ = LibHealpix.pix2ang_ring(nside(lwa1), pix)
        galactic = Direction(dir"GALACTIC", ϕ*radians, (π/2-θ)*radians)
        j2000 = measure(frame, galactic, dir"J2000")
        ra = longitude(j2000)
        dec = latitude(j2000)
        if dec < deg2rad(-30)
            mask[pix] = false
        end
        for source in sources
            if acosd(j2000.x*source.x + j2000.y*source.y + j2000.z*source.z) < 2resolution
                mask[pix] = false
            end
        end
    end

    # Subtract sources from the LWA1 maps
    frame = ReferenceFrame()
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
            lwa1[pixel] -= g
        end
    end
    for source in sources
        direction = measure(frame, source, dir"J2000")
        θ = π/2-latitude(direction)
        ϕ = longitude(direction)
        vec = LibHealpix.ang2vec(θ, ϕ)
        rhat = vec / norm(vec)
        north = [0, 0, 1]
        north = north - dot(rhat, north)*rhat
        north = north / norm(north)
        east = cross(north, rhat)
        disc = LibHealpix.query_disc(lwa1, θ, ϕ, deg2rad(10), inclusive=true)
        x = Float64[]
        y = Float64[]
        for pix in disc
            myvec = LibHealpix.pix2vec_ring(nside(lwa1), Int(pix))
            push!(x, asind(dot(myvec, east)))
            push!(y, asind(dot(myvec, north)))
        end

        opt = Opt(:LN_SBPLX, 5)
        ftol_rel!(opt, 1e-10)
        min_objective!(opt, (params, _)->residual(lwa1, disc, x, y, params))
        lower_bounds!(opt, [1, 1, 1, -π/2, 1])
        upper_bounds!(opt, [1e6, 10, 10, +π/2, 1e6])
        @time minf, params, ret = optimize(opt, [1, 5, 5, 0, 1])
        @show minf, params, ret
        remove(disc, x, y, params)
    end

    lwa1_original = deepcopy(lwa1)
    lwa1_original = Pipeline.MModes.rotate_from_j2000(4, "rainy", lwa1_original)
    lwa1_original = Pipeline.MModes.rotate_to_galactic(4, "rainy", lwa1_original)

    # Filter the LWA1 map in the same way the OVRO-LWA maps are filtered
    alm = map2alm(Pipeline.MModes.rotate_from_j2000(4, "rainy", lwa1), 500, 500)
    Pipeline.MModes.apply_wiener_filter!(alm, 0:0)
    lwa1 = Pipeline.MModes.rotate_to_galactic(4, "rainy", alm2map(alm, nside(lwa1)))
    writehealpix(filename, lwa1, replace=true)

    # Load the two nearest OVRO-LWA maps and interpolate to the right frequency
    ovro_ν = [36.528e6, 41.760e6, 46.992e6, 52.224e6, 57.456e6, 62.688e6, 67.920e6, 73.152e6]
    idx = searchsortedlast(ovro_ν, ν)
    spws = 4:2:18
    spw1 = spws[idx]
    spw2 = spws[idx+1]
    wgt1 = 1 - (ν - ovro_ν[idx])/(ovro_ν[idx+1] - ovro_ν[idx])
    wgt2 = 1 - wgt1
    map1 = readhealpix(joinpath(Pipeline.Common.getdir(spw1),
                                "map-restored-registered-rainy-itrf.fits"))
    map2 = readhealpix(joinpath(Pipeline.Common.getdir(spw2),
                                "map-restored-registered-rainy-itrf.fits"))
    map1 = map1 * (BPJSpec.Jy * (BPJSpec.c/ovro_ν[idx])^2 / (2*BPJSpec.k))
    map2 = map2 * (BPJSpec.Jy * (BPJSpec.c/ovro_ν[idx+1])^2 / (2*BPJSpec.k))
    ovro_lwa = wgt1*map1 + wgt2*map2
    ovro_lwa = Pipeline.MModes.rotate_to_galactic(4, "rainy", ovro_lwa)
    ovro_lwa = smooth(ovro_lwa, resolution, nside(lwa1))

    lwa1_original.pixels, lwa1.pixels, ovro_lwa.pixels, mask
end

