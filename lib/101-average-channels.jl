module Driver

using BPJSpec
using YAML

include("Project.jl")

struct Config
    input  :: String
    output :: String
    Navg   :: Int # the number of channels to average together
    # TODO group based on frequency value instead of blindly counting channels. The blind counting
    # is a problem when there are gaps in the frequency coverage (when we've decided to omit a bad
    # channel).
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["input"], dict["output"], dict["Navg"])
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    average(project, config)
    Project.touch(project, config.output)
end

function average(project, config)
    path = Project.workspace(project)
    average = BPJSpec.average_frequency_channels
    input   = BPJSpec.load(joinpath(path, config.input))
    storage = MultipleFiles(joinpath(path, config.output))
    output  = average(input, config.Navg, storage=storage, progress=true)
end

end

