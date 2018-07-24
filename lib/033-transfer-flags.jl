# Take flags from one set of m-modes and apply them to a different set of m-modes.
module Driver

using BPJSpec
using YAML

include("Project.jl")

struct Config
    input_to_flag :: String
    input_already_flagged :: String
    output :: String
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["input-to-flag"],
           dict["input-already-flagged"],
           dict["output"])
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    transfer_flags(project, config)
end

function transfer_flags(project, config)
    path = Project.workspace(project)
    to_flag         = BPJSpec.load(joinpath(path, config.input_to_flag))
    already_flagged = BPJSpec.load(joinpath(path, config.input_already_flagged))
    output = similar(to_flag, MultipleFiles(joinpath(path, config.output))) |> ProgressBar
    @. output = _transfer_flags(to_flag, already_flagged)
end

function _transfer_flags(to_flag, already_flagged)
    output = copy(to_flag)
    output[already_flagged .== 0] = 0
    output
end

end

