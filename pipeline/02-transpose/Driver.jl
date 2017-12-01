module Driver

using JLD2
using ProgressMeter
using TTCal
using Unitful

include("../lib/Common.jl"); using .Common

function transpose(spw, name)
    path =  getdir(spw, name)
    meta = getmeta(spw, name)

    jldopen(joinpath(path, "calibrated-visibilities.jld2"), "r") do input_file
        frequencies = input_file["frequencies"]
        times = input_file["times"]
        jldopen(joinpath(path, "transposed-visibilities.jld2"), "w") do output_file
            for frequency = 1:length(frequencies)
                transpose(input_file, output_file, frequency, length(times), Nbase(meta))
            end
            output_file["frequencies"] = frequencies
            output_file["times"] = times
            output_file["Nfreq"] = length(frequencies)
            output_file["Ntime"] = length(times)
        end
    end
end

function transpose(input_file, output_file, frequency, Ntime, Nbase)
    output = zeros(Complex128, 2, Nbase, Ntime)
    prg = Progress(Ntime)
    objname(i) = @sprintf("%06d", i)
    for time = 1:Ntime
        data = input_file[objname(time)]
        pack!(output, data, frequency, time)
        next!(prg)
    end
    output_file[objname(frequency)] = output
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

