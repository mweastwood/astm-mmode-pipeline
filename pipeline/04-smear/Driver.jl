module Driver

using JLD2
using ProgressMeter
using TTCal

include("../lib/Common.jl"); using .Common

function smear(spw, name)
    _smear(spw, name)
    #image = residuals(spw, name, source_dictionary[source])
    #@show image joinpath(getdir(spw, name), lowercase(replace(source, " ", "-"))*".fits")
    #mv(image, joinpath(getdir(spw, name), lowercase(replace(source, " ", "-"))*".fits"),
    #   remove_destination=true)
    nothing
end

function _smear(spw, name)
    local accumulation, metadata
    jldopen(joinpath(getdir(spw, name), "calibrated-visibilities.jld2"), "r") do file
        metadata = file["metadata"]
        accumulation = zeros(Complex128, 2, Nfreq(metadata), Nbase(metadata))
        prg = Progress(Ntime(metadata))
        for index = 1:Ntime(metadata)
            data = file[o6d(index)]
            accumulation .+= data
            next!(prg)
        end
    end
    dataset = array_to_ttcal(accumulation, metadata, 1)
    jldopen(joinpath(getdir(spw, name), "smeared-visibilities.jld2"), "w") do file
        file["dataset"] = dataset
    end
    accumulation, metadata
end

#function do_the_work(spw, name, data, metadata, time, direction)
#    ttcal = array_to_ttcal(data, metadata, time)
#    Common.flag!(spw, name, ttcal)
#    rotate_phase_center!(ttcal, direction)
#    ttcal_to_array(ttcal)
#end
#
#function do_the_image(spw, name, accumulation, frequencies)
#    dada = first(listdadas(spw, name))
#    ms = dada2ms(spw, dada, name)
#    metadata = TTCal.Metadata(ms)
#    output = zeros(Complex64, 4, Nfreq(metadata), Nbase(metadata))
#    for (idx, ν) in enumerate(frequencies)
#        jdx = first(find(ν .== metadata.frequencies))
#        for α = 1:Nbase(metadata)
#            output[1, jdx, α] = accumulation[1, idx, α]
#            output[4, jdx, α] = accumulation[2, idx, α]
#        end
#    end
#    ms["CORRECTED_DATA"] = output
#    Tables.close(ms)
#    image_path = "/dev/shm/mweastwood/image"
#    name = wsclean(ms.path, image_path)
#    Tables.delete(ms)
#    image_path*".fits"
#end

end

