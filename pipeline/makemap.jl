function makemap(spw; pass=1)
    dir = getdir(spw)
    meta = getmeta(spw)
    alm = load(joinpath(dir, "alm-$pass.jld"), "alm")
    map = alm2map(alm, 512)

    ## TODO: does this need a factor of the beam solid angle?
    #mmodes = MModes(joinpath(dir, "mmodes")) # read the frequency from the m-modes
    #map = map * (BPJSpec.Jy * (BPJSpec.c/mmodes.frequencies[1])^2 / (2*BPJSpec.k))

    # rotate the map to Galactic coordinates
    frame = TTCal.reference_frame(meta)
    z = Direction(dir"ITRF", 0.0degrees, 90degrees)
    z_ = measure(frame, z, dir"GALACTIC")
    x = Direction(dir"ITRF", 0.0degrees, 0.0degrees)
    x_ = measure(frame, x, dir"GALACTIC")
    zvec = [z_.x, z_.y, z_.z]
    xvec = [x_.x, x_.y, x_.z]
    yvec = cross(zvec, xvec)
    θ = zeros(length(map))
    ϕ = zeros(length(map))
    for idx = 1:length(map)
        vec = LibHealpix.pix2vec_ring(nside(map), idx)
        θ[idx] = acos(dot(vec, zvec))
        ϕ[idx] = atan2(dot(vec, yvec), dot(vec, xvec))
    end
    pixels = LibHealpix.interpolate(map, θ, ϕ)
    newmap = HealpixMap(pixels)

    writehealpix(joinpath(dir, "map-$pass.fits"), newmap, coordsys="G", replace=true)

    nothing
end

