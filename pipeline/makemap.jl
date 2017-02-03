function makemap(spw, input="alm", output="map")
    Lumberjack.info("Creating a map for spectral window $spw")
    dir = getdir(spw)
    meta = getmeta(spw)

    path_to_alm = joinpath(dir, input*".jld")
    Lumberjack.info("Using the spherical harmonic coefficients located at $path_to_alm")
    alm = load(joinpath(dir, input*".jld"), "alm")

    Lumberjack.info("Running alm2map")
    map = alm2map(alm, 2048)

    Lumberjack.info("Converting to temperature units")
    # TODO: does this need a factor of the beam solid angle?
    mmodes = MModes(joinpath(dir, "mmodes")) # read the frequency from the m-modes
    map = map * (BPJSpec.Jy * (BPJSpec.c/mmodes.frequencies[1])^2 / (2*BPJSpec.k))

    Lumberjack.info("Rotating the map to J2016 coordinates")
    newmap = HealpixMap(Float64, 2048)
    frame = TTCal.reference_frame(meta)
    j2016_z = Direction(dir"JTRUE", 0.0degrees, 90degrees)
    j2016_z_in_itrf = measure(frame, j2016_z, dir"ITRF")
    j2016_x = Direction(dir"JTRUE", 0.0degrees, 0.0degrees)
    j2016_x_in_itrf = measure(frame, j2016_x, dir"ITRF")
    z = [j2016_z_in_itrf.x, j2016_z_in_itrf.y, j2016_z_in_itrf.z]
    x = [j2016_x_in_itrf.x, j2016_x_in_itrf.y, j2016_x_in_itrf.z]
    y = cross(z, x)
    p = Progress(length(newmap), "Rotating: ")
    for i = 1:length(newmap)
        vec = LibHealpix.pix2vec_ring(nside(newmap), i)
        vec′ = vec[1]*x + vec[2]*y + vec[3]*z
        j = LibHealpix.vec2pix_ring(nside(newmap), vec′)
        newmap[i] = map[j]
        next!(p)
    end

    Lumberjack.info("Creating a low resolution version of the map")
    newalm = map2alm(newmap, lmax(alm), mmax(alm), iterations=10)
    lowresmap = alm2map(newalm, 512)

    path_to_highres_map = joinpath(dir, output*"-2048.fits")
    Lumberjack.info("Saving a high resolution map to $path_to_highres_map")
    writehealpix(path_to_highres_map, newmap, replace=true)

    path_to_lowres_map = joinpath(dir, output*"-512.fits")
    Lumberjack.info("Saving a low resolution map to $path_to_lowres_map")
    writehealpix(path_to_lowres_map, lowresmap, replace=true)

    nothing
end

