module Driver

using JLD2
using ProgressMeter
using TTCal

include("../lib/Common.jl"); using .Common

function transpose(spw, name)
    path = getdir(spw, name)
    jldopen(joinpath(path, "calibrated-visibilities.jld2"), "r") do input_file
        metadata = input_file["metadata"]
        jldopen(joinpath(path, "transposed-visibilities.jld2"), "w") do output_file
            for frequency = 1:Nfreq(metadata)
                transpose(input_file, output_file, metadata, frequency)
            end
            output_file["metadata"] = metadata
        end
    end
end

function transpose(input_file, output_file, metadata, frequency)
    output = zeros(Complex128, 2, Nbase(metadata), Ntime(metadata))
    prg = Progress(Ntime(metadata))
    for time = 1:Ntime(metadata)
        data = input_file[o6d(time)]
        pack!(output, data, frequency, time)
        next!(prg)
    end
    output_file[o6d(frequency)] = output
end

function pack!(output, data, frequency, time)
    _, Nbase, Ntime = size(output)
    for α = 1:Nbase
        output[1, α, time] = data[1, frequency, α]
        output[2, α, time] = data[2, frequency, α]
    end
    output
end

end

