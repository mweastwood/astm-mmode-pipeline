# The predicted m-modes don't have any flags applied to them, this routine will take flags from a
# different set of m-modes, and apply them to the predicted m-modes.
module Driver

using BPJSpec
using YAML

include("Project.jl")

struct Config
    input_predicted :: String
    input_measured  :: String
    output          :: String
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["input-predicted"],
           dict["input-measured"],
           dict["output"])
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    transfer_flags(project, config)
end

function transfer_flags(project, config)
    path = Project.workspace(project)
    predicted = BPJSpec.load(joinpath(path, config.input_predicted))
    measured  = BPJSpec.load(joinpath(path, config.input_measured))
    output = similar(predicted, MultipleFiles(joinpath(path, config.output))) |> ProgressBar
    @. output = _transfer_flags(predicted, measured)
end

function _transfer_flags(predicted, measured)
    output = copy(predicted)
    output[measured .== 0] = 0
    output
end

end

