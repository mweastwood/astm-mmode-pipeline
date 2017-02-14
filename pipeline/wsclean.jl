function wsclean(name; weight="uniform", minuvw=0, j=1)
    if endswith(name, "ms")
        ms_name = name
        name = replace(name, ".ms", "")
    else
        ms_name = name*".ms"
    end
    readstring(`wsclean -j $j -size 2048 2048 -scale 0.0625 -weight $weight -minuv-l $minuvw -name $name $ms_name`)
    image_name = name*"-image.fits"
    dirty_name = name*"-dirty.fits"
    rm(dirty_name)
    mv(image_name, name*".fits", remove_destination=true)
end

function wsclean(input, output; weight="uniform", minuvw=0, j = 1)
    readstring(`wsclean -j $j -size 2048 2048 -scale 0.0625 -weight $weight -minuv-l $minuvw -name $output $input`)
    rm(output*"-dirty.fits")
    mv(output*"-image.fits", output*".fits", remove_destination=true)
end

function fits2png(input, output, lower_limit=-300, upper_limit=+800)
    fits = FITS(input*".fits")
    img = read(fits[1])[:,:,1,1]
    img -= lower_limit
    img /= upper_limit - lower_limit
    img = clamp(img, 0, 1)
    img = flipdim(img', 1)
    save(output, img)
end

