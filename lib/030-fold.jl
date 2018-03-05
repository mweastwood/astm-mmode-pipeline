module Driver

using JLD2
using ProgressMeter
using TTCal
using YAML

include("Project.jl")

struct Config
    input  :: String
    output :: String
    integrations_per_day :: Int
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["input"], dict["output"], dict["integrations-per-day"])
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    fold(project, config)
    Project.touch(project, config.output)
end

function fold(project, config)
    path = Project.workspace(project)
    jldopen(joinpath(path, config.input*".jld2"), "r") do input_file
        metadata = input_file["metadata"]
        jldopen(joinpath(path, config.output*".jld2"), "w") do output_file
            output_file["metadata"] = metadata
            for frequency = 1:Nfreq(metadata)
                fold(input_file, output_file, metadata, frequency, config.integrations_per_day)
            end
        end
    end
end

function fold(input_file, output_file, metadata, frequency, integrations_per_day)
    output  = zeros(Complex128, Nbase(metadata), integrations_per_day)
    weights = zeros(       Int, Nbase(metadata), integrations_per_day)
    prg = Progress(Ntime(metadata))
    for time = 1:Ntime(metadata)
        data = input_file[o6d(time)]
        pack!(output, weights, data, frequency, time, integrations_per_day)
        next!(prg)
    end
    output ./= weights
    output[isnan.(output)] = 0
    output_file[o6d(frequency)] = output
end

function pack!(output, weights, data, frequency, time, integrations_per_day)
    i = mod1(time, integrations_per_day)
    Nbase = size(output, 1)
    for α = 1:Nbase
        xx = data[1, frequency, α]
        yy = data[2, frequency, α]
        if xx != 0 && yy != 0
            output[α, i]  += xx
            output[α, i]  += yy
            output[α, i]  /= 2 # we take the convention I = (xx+yy)/2
            weights[α, i] += 1
        end
    end
end

o6d(i) = @sprintf("%06d", i)

end

