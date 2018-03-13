module Driver

using BPJSpec
using YAML

include("Project.jl")

struct Config
    input_mmodes :: String
    input_transfermatrix :: String
    output_mmodes :: String
    output_transfermatrix :: String
    Navg :: Int # the number of channels to average together
    # TODO group based on frequency value instead of blindly counting channels. The blind counting
    # is a problem when there are gaps in the frequency coverage (when we've decided to omit a bad
    # channel).
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["input-m-modes"], dict["input-transfer-matrix"],
           dict["output-m-modes"], dict["output-transfer-matrix"], dict["Navg"])
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    average(project, config)
    Project.touch(project, config.output_mmodes)
end

function average(project, config)
    path = Project.workspace(project)
    average = BPJSpec.average_frequency_channels

    mmodes  =  BPJSpec.load(joinpath(path, config.input_mmodes))
    storage = MultipleFiles(joinpath(path, config.output_mmodes))
    mmodes′ = average(mmodes, config.Navg, storage=storage, progress=true)

    transfermatrix  = BPJSpec.load(joinpath(path, config.input_transfermatrix))
    storage = MultipleFiles(joinpath(path, config.output_transfermatrix))
    transfermatrix′ = average(transfermatrix, config.Navg, storage=storage, progress=true)
end

end

