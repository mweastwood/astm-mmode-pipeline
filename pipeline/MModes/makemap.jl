function makemap(spw, dataset, target)
    dir = getdir(spw)
    alm = load(joinpath(dir, "$target-$dataset.jld"), "alm")
    makemap(spw, alm, dataset, target)
end

function makemap(spw, alm::Alm, dataset, target)
    dir = getdir(spw)
    meta = getmeta(spw, dataset)
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
    galactic = HealpixMap(pixels)

    # rotate the map to Galactic coordinates
    frame = TTCal.reference_frame(meta)
    z = Direction(dir"ITRF", 0.0degrees, 90degrees)
    z_ = measure(frame, z, dir"J2000")
    x = Direction(dir"ITRF", 0.0degrees, 0.0degrees)
    x_ = measure(frame, x, dir"J2000")
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
    j2000 = HealpixMap(pixels)

    output = replace(target, "alm", "map")*"-$dataset"
    writehealpix(joinpath(dir, output*"-galactic.fits"), galactic, coordsys="G", replace=true)
    writehealpix(joinpath(dir, output*"-j2000.fits"), j2000, coordsys="C", replace=true)
    writehealpix(joinpath(dir, output*"-itrf.fits"), map, coordsys="C", replace=true)

    nothing
end

