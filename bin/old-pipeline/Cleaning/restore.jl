function restore(spw, dataset, target)
    directory = joinpath(getdir(spw), "psf")
    psf = load(joinpath(directory, "psf.jld"), "psf")
    major_σ, minor_σ, angle = load(joinpath(directory, "gaussian.jld"), "major", "minor", "angle")

    directory = joinpath(getdir(spw), "cleaning", target)
    residual_alm, degraded_alm, clean_components = load(joinpath(directory, "final.jld"),
                                                        "residual_alm", "degraded_alm",
                                                        "clean_components")

    restored_alm = Alm(1500, 1500, residual_alm + degraded_alm)
    restored_map = alm2map(restored_alm, 2048)

    restore!(restored_map, clean_components, psf, major_σ, minor_σ, angle)
    if contains(target, "odd")
        target = "map-odd-restored"
    elseif contains(target, "even")
        target = "map-even-restored"
    else
        if contains(target, "new")
            target = "new-map-restored"
        else
            target = "map-restored"
        end
    end
    save(joinpath(getdir(spw), "$target-$dataset.jld"), "map", restored_map.pixels)
    writehealpix(joinpath(getdir(spw), "$target-$dataset-itrf.fits"),
                 restored_map, replace=true)
    writehealpix(joinpath(getdir(spw), "$target-$dataset-galactic.fits"),
                 MModes.rotate_to_galactic(spw, dataset, restored_map), replace=true)
    writehealpix(joinpath(getdir(spw), "$target-$dataset-j2000.fits"),
                 MModes.rotate_to_j2000(spw, dataset, restored_map), replace=true)
end

function restore!(restored_map, clean_components, psf, major_σ, minor_σ, angle)
    pixels = find(clean_components)
    N = length(pixels)
    prg = Progress(length(pixels))
    for pixel in pixels
        ring = searchsortedlast(psf.pixels, pixel)
        vec = LibHealpix.pix2vec_ring(nside(restored_map), pixel)
        θ, ϕ = LibHealpix.vec2ang(vec)
        north = [0, 0, 1]
        north -= dot(north, vec)*vec
        north /= norm(north)
        east = cross(north, vec)
        amplitude = clean_components[pixel]*psf.amplitudes[ring]
        disc = query_disc(restored_map, θ, ϕ, deg2rad(1))
        for disc_pixel in disc
            disc_vec = LibHealpix.pix2vec_ring(nside(restored_map), Int(disc_pixel))
            x = asind(dot(disc_vec, east)) * 60
            y = asind(dot(disc_vec, north)) * 60
            value = gaussian(x, y, amplitude, major_σ[ring], minor_σ[ring], deg2rad(angle[ring]))
            restored_map[disc_pixel] += value
        end
        next!(prg)
    end
end

