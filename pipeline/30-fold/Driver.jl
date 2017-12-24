module Driver

using JLD2
using ProgressMeter
using TTCal

include("../lib/Common.jl"); using .Common

function fold(spw, name)
    path =  getdir(spw, name)
    jldopen(joinpath(path, "peeled-visibilities.jld2"), "r") do input_file
        metadata = input_file["metadata"]
        jldopen(joinpath(path, "folded-visibilities.jld2"), "w") do output_file
            for frequency = 1:Nfreq(metadata)
                fold(input_file, output_file, frequency)
            end
            output_file["metadata"] = metadata
        end
    end
end

function fold(input_file, output_file, frequency)
    input_data  = input_file[o6d(frequency)]
    output_data = zeros(Complex128, size(input_data, 2), 6628)
    pack!(output_data, input_data)
    output_file[o6d(frequency)] = output_data
end

function pack!(output, input)
    _, Nbase, Ntime = size(input)
    Ntime′  = size(output, 2)
    weights = zeros(Int, size(output))
    for i = 1:Ntime
        i′ = mod1(i, Ntime′)
        for α = 1:Nbase
            output[α, i′]  += input[1, α, i]
            output[α, i′]  += input[2, α, i]
            weights[α, i′] += 1
        end
    end
    output ./= weights
end

end

