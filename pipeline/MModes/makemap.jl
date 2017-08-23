function makemap(spw, dataset, target, nside=2048)
    dir = getdir(spw)
    alm = load(joinpath(dir, "$target-$dataset.jld"), "alm")
    makemap(spw, alm, dataset, target, nside)
end

function makemap(spw, alm::Alm, dataset, target, nside)
    dir = getdir(spw)
    meta = getmeta(spw, dataset)
    map = alm2map(alm, nside)

    ## TODO: does this need a factor of the beam solid angle?
    #mmodes = MModes(joinpath(dir, "mmodes")) # read the frequency from the m-modes
    #map = map * (BPJSpec.Jy * (BPJSpec.c/mmodes.frequencies[1])^2 / (2*BPJSpec.k))

    galactic = rotate_to_galactic(spw, dataset, map)
    j2000 = rotate_to_j2000(spw, dataset, map)

    output = replace(target, "alm", "map")*"-$dataset"
    writehealpix(joinpath(dir, output*"-$nside-galactic.fits"), galactic, coordsys="G", replace=true)
    writehealpix(joinpath(dir, output*"-$nside-j2000.fits"), j2000, coordsys="C", replace=true)
    writehealpix(joinpath(dir, output*"-$nside-itrf.fits"), map, coordsys="C", replace=true)

    nothing
end

function rotate_to_galactic(spw, dataset, map)
    dir = getdir(spw)
    meta = getmeta(spw, dataset)
    frame = TTCal.reference_frame(meta)
    z = Direction(dir"ITRF", 0.0degrees, 90degrees)
    z_ = measure(frame, z, dir"GALACTIC")
    x = Direction(dir"ITRF", 0.0degrees, 0.0degrees)
    x_ = measure(frame, x, dir"GALACTIC")
    zvec = [z_.x, z_.y, z_.z]
    xvec = [x_.x, x_.y, x_.z]
    yvec = cross(zvec, xvec)
    pixels = zeros(length(map))
    for idx = 1:length(map)
        vec = LibHealpix.pix2vec_ring(nside(map), idx)
        θ = acos(dot(vec, zvec))
        ϕ = atan2(dot(vec, yvec), dot(vec, xvec))
        pixels[idx] = LibHealpix.interpolate(map, θ, ϕ)
    end
    HealpixMap(pixels)
end

function rotate_to_j2000(spw, dataset, map)
    dir = getdir(spw)
    meta = getmeta(spw, dataset)
    frame = TTCal.reference_frame(meta)
    z = Direction(dir"ITRF", 0.0degrees, 90degrees)
    z_ = measure(frame, z, dir"J2000")
    x = Direction(dir"ITRF", 0.0degrees, 0.0degrees)
    x_ = measure(frame, x, dir"J2000")
    zvec = [z_.x, z_.y, z_.z]
    xvec = [x_.x, x_.y, x_.z]
    yvec = cross(zvec, xvec)
    pixels = zeros(length(map))
    for idx = 1:length(map)
        vec = LibHealpix.pix2vec_ring(nside(map), idx)
        θ = acos(dot(vec, zvec))
        ϕ = atan2(dot(vec, yvec), dot(vec, xvec))
        pixels[idx] = LibHealpix.interpolate(map, θ, ϕ)
    end
    HealpixMap(pixels)
end

