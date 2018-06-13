module WSClean

using CasaCore.Tables
using TTCal
#using FITSIO
using YAML

include("Project.jl")
include("CreateMeasurementSet.jl")

struct Config
    weight :: String
    minuvw :: Float64
    j :: Int
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["weight"], dict["minuvw"], dict["j"])
end

function run(config::Config, input::TTCal.Dataset, output; mspath="", deletems=true)
    if mspath == ""
        path = joinpath(Project.temp(), randstring(4)*".ms")
    else
        path = mspath
    end
    ms = CreateMeasurementSet.create(input, path)
    run(config, ms, output)
    if deletems
        Tables.delete(ms)
    else
        Tables.close(ms)
    end
end

function run(config::Config, input::Table, output)
    Tables.close(input)
    readstring(`wsclean -j $(config.j) -size 2048 2048 -scale 0.0625
                        -weight $(config.weight) -minuv-l $(config.minuvw)
                        -name $output $(input.path)`)
    image_name = output*"-image.fits"
    dirty_name = output*"-dirty.fits"
    rm(dirty_name)
    mv(image_name, output*".fits", remove_destination=true)
    output*".fits"
end

#function fits2png(input, output, lower_limit=-300, upper_limit=+800)
#    fits = FITS(input*".fits")
#    img = read(fits[1])[:,:,1,1]
#    img -= lower_limit
#    img /= upper_limit - lower_limit
#    img = clamp(img, 0, 1)
#    img = flipdim(img', 1)
#    save(output, img)
#end

end

