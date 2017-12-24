module Driver

using JLD2
using ProgressMeter
using TTCal

include("../lib/Common.jl"); using .Common

const DAY = 6628

function fold(spw, name)
    path =  getdir(spw, name)
    jldopen(joinpath(path, "peeled-visibilities.jld2"), "r") do input_file
        metadata = input_file["metadata"]
        jldopen(joinpath(path, "folded-visibilities.jld2"), "w") do output_file
            for frequency = 1:Nfreq(metadata)
                fold(input_file, output_file, metadata, frequency)
            end
            output_file["metadata"] = metadata
        end
    end
end

function fold(input_file, output_file, metadata, frequency)
    output  = zeros(Complex128, Nbase(metadata), DAY)
    weights = zeros(       Int, Nbase(metadata), DAY)
    prg = Progress(Ntime(metadata))
    for time = 1:Ntime(metadata)
        data = input_file[o6d(time)]
        pack!(output, weights, data, frequency, time)
        next!(prg)
    end
    output ./= weights
    output_file[o6d(frequency)] = output
end

function pack!(output, weights, data, frequency, time)
    i = mod1(time, DAY)
    Nbase = size(output, 1)
    for α = 1:Nbase
        xx = data[1, frequency, α]
        yy = data[2, frequency, α]
        if xx != 0 && yy != 0
            output[α, i]  += xx
            output[α, i]  += yy
            weights[α, i] += 1
        end
    end
end

end

