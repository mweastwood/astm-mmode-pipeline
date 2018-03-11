module Driver

using FileIO, JLD2
using ProgressMeter
using TTCal
using BPJSpec
using Unitful
using YAML

include("Project.jl")

module Fold
    include("030-fold.jl")
end

struct Config
    input  :: String
    output :: String
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["input"], dict["output"])
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    transpose(project, config, project_file)
    Project.touch(project, config.output)
end

function transpose(project, transpose_config, project_file)
    path = Project.workspace(project)
    metadata = FileIO.load(joinpath(path, transpose_config.input*".jld2"), "metadata")

    fold_project = Fold.Driver.Project.load(project_file)
    fold_config = Fold.Driver.Config(transpose_config.input, transpose_config.output,
                                     Ntime(metadata))
    Fold.Driver.fold(fold_project, fold_config)
end

end

