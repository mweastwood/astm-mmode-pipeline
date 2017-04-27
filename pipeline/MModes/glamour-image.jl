function glamour(spw)
    dir = getdir(spw)
    map = readhealpix(joinpath(dir, "map-rfi-subtracted-peeled-rainy-galactic.fits"))
    mask_the_map!(spw, map)

    output = joinpath(dir, "glamour-shot.png")
    image = mollweide(map)
    image -= minimum(image)
    image /= maximum(image)
    image = flipdim(image, 1)
    save(output, image)
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

