module Driver

using JLD2
using ProgressMeter
using TTCal

include("../lib/Common.jl"); using .Common

function transpose_raw(spw, name)
    transpose(spw, name, "raw-visibilities.jld2",
                         "transposed-raw-visibilities.jld2")
end

#function transpose_subrfi_stationary(spw, name)
#    transpose(spw, name, "subrfi-stationary-visibilities.jld2",
#                         "transposed-subrfi-stationary-visibilities.jld2")
#end

function transpose(spw, name, input, output)
    path = getdir(spw, name)
    jldopen(joinpath(path, input), "r") do input_file
        metadata = input_file["metadata"]
        jldopen(joinpath(path, output), "w") do output_file
            for frequency = 1:Nfreq(metadata)
                _transpose(input_file, output_file, metadata, frequency)
            end
            output_file["metadata"] = metadata
        end
    end
end

function _transpose(input_file, output_file, metadata, frequency)
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

