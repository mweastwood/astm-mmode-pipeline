module Driver

using JLD2
using ProgressMeter
using TTCal
using BPJSpec
using YAML

include("Project.jl")

struct Config
    input  :: String
    output :: String
    mmax   :: Int
    delete_input :: Bool
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["input"], dict["output"], dict["mmax"], dict["delete_input"])
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    getmmodes(project, config)
    if config.delete_input
        rm(joinpath(Project.workspace(project), config.input*".jld2"))
    end
    Project.touch(project, config.output)
end

function getmmodes(project, config)
    path = Project.workspace(project)
    jldopen(joinpath(path, config.input*".jld2"), "r") do input_file
        ttcal_metadata   = input_file["metadata"]
        bpjspec_metadata = BPJSpec.from_ttcal(ttcal_metadata)
        mmodes = MModes(joinpath(path, config.output), bpjspec_metadata, config.mmax)
        prg = Progress(Nfreq(ttcal_metadata))
        for index = 1:Nfreq(ttcal_metadata)
            _getmmodes(mmodes, input_file[o6d(index)], index)
            next!(prg)
        end
    end
end

function _getmmodes(mmodes, array, index)
    # put time on the fast axis
    transposed_array = permutedims(array, (2, 1))
    # compute the m-modes
    BPJSpec.compute!(mmodes, transposed_array, mmodes.metadata.frequencies[index])
end

o6d(i) = @sprintf("%06d", i)

end

