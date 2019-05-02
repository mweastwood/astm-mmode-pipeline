module Driver

using FileIO, JLD2
using ProgressMeter
using BPJSpec
using Unitful, UnitfulAstro
using YAML

include("Project.jl")

struct Config
    input     :: String # input visibilities
    output    :: String # output visibilities
    hierarchy :: String
    sefd :: Vector{Float64} # Noise temperature at each sidereal time
    constant :: Bool # If true, the SEFD is changed to be constant with time
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["input"],
           dict["output"],
           dict["hierarchy"],
           dict["sefd"])
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    mess_with_noise(project, config)
end

function mess_with_gains(project, config)
    path   = Project.workspace(project)
    input  = BPJSpec.load(joinpath(path, config.input))
    output = similar(input, SingleFile(joinpath(path, config.output)))
    sefd   = load(joinpath(path, config.sefd))
    if config.constant
        sefd[:] = mean(sefd)
    end
    mess_with_noise(input, output, ant1, ant2, hierarchy, sefd)
end

function mess_with_noise(input, output, ant1, ant2, hierarchy, sefd)
    for β = 1:Nfreq
        N = uconvert(NoUnits, input.bandwidth[β]*13u"s")
        block = input[β]
        for α = 1:size(block, 2), idx = 1:size(block, 1)
            block[idx, α] == 0 && continue
            block[idx, α] += sefd[idx] .* complex(randn(), randn()) / √2
        end
        output[β] = block
    end
end

end

