function glamour(spw, filename="map-wiener-filtered-rainy-2048-galactic.fits";
                 min=0, max=0)
    dir = getdir(spw)
    map = readhealpix(joinpath(dir, filename))
    mask_the_map!(spw, map)

    # Get to units of K
    meta = getmeta(spw, "rainy")
    ν = meta.channels[55]
    map = map * (BPJSpec.Jy * (BPJSpec.c/ν)^2 / (2*BPJSpec.k))

    str = @sprintf("spw%02d", spw)
    output = joinpath(dir, "$str-glamour-shot-$(replace(filename, ".fits", "")).jld")
    image = mollweide(map)
    save(output, "image", image, "frequency", ν)

    #output = joinpath(dir, "glamour-shot-$(replace(filename, ".fits", "")).png")
    #image = mollweide(map)
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

