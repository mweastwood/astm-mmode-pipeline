function restore(spw)
    dir = joinpath(getdir(spw), "cleaning")
    residual_map, clean_components = load(joinpath(dir, "final.jld"),
                                          "residual_map", "clean_components")
    restored_map = HealpixMap(copy(residual_map))
    restore!(restored_map, clean_components)
    writehealpix(joinpath(dir, "restored-test.fits"), restored_map, replace=true)
end

function restore!(restored_map, clean_components)
    pixels = find(clean_components)
    prg = Progress(length(pixels))
    for pixel in pixels[1:1]
        vec = LibHealpix.pix2vec_ring(nside(restored_map), pixel)
        θ, ϕ = LibHealpix.vec2ang(vec)
        disc = query_disc(restored_map, θ, ϕ, deg2rad(1))
        @show length(disc)
        for disc_pixel in disc
            disc_vec = LibHealpix.pix2vec_ring(nside(restored_map), Int(disc_pixel))
            distance = acosd(clamp(dot(vec, disc_vec), -1, 1))
            value = 1e6*clean_components[pixel] * exp(-distance^2/(2*(10/60)^2))
            restored_map[disc_pixel] += value
        end
        next!(prg)
    end
end

