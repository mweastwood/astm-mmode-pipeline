function glamour(spw, dataset, target; min=0, max=0)
    dir = getdir(spw)
    pixels = load(joinpath(dir, "$target-$dataset.jld"), "map")
    map = rotate_to_galactic(spw, dataset, HealpixMap(pixels))
    mask_the_map!(spw, map)

    # Get to units of K
    meta = getmeta(spw, "rainy")
    ν = meta.channels[55]
    map = map * (BPJSpec.Jy * (BPJSpec.c/ν)^2 / (2*BPJSpec.k))

    str = @sprintf("spw%02d", spw)
    output = joinpath(dir, "glamour-$target-$dataset.jld")
    image = mollweide(map, (2048, 4096))
    save(output, "image", image, "frequency", ν, "map", map.pixels, compress=true)

    #output = joinpath(dir, "$target-$dataset-galactic.png")
    #@show maximum(image) minimum(image)
    #if min == max == 0
    #    image -= minimum(image)
    #    image /= maximum(image)
    #else
    #    image -= min
    #    image /= (max-min)
    #    image = clamp(image, 0, 1)
    #end
    #image = flipdim(image, 1)
    #@show output
    #@show size(image) maximum(image) minimum(image)
    #save(output, image)
end

function mask_the_map!(spw, map)
    meta = getmeta(spw, "rainy")
    frame = TTCal.reference_frame(meta)

    north_itrf = Direction(dir"ITRF", 0degrees, 90degrees)
    north_galactic = measure(frame, north_itrf, dir"GALACTIC")
    north_vec = [north_galactic.x, north_galactic.y, north_galactic.z]

    sun = Direction(dir"SUN")
    sun_galactic = measure(frame, sun, dir"GALACTIC")
    sun_vec = [sun_galactic.x, sun_galactic.y, sun_galactic.z]

    for pixel = 1:length(map)
        vec = LibHealpix.pix2vec_ring(nside(map), pixel)

        θ = acosd(dot(vec, north_vec))
        latitude = 90 - θ
        if latitude < -30
            map[pixel] = 0
        end

        θ = acosd(dot(vec, sun_vec))
        if θ < 2
            map[pixel] = 0
        end
    end
end

