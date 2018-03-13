module Driver

using BPJSpec
using YAML

include("Project.jl")

struct Config
    input_mmodes :: String
    input_transfermatrix :: String
    output_mmodes :: String
    output_transfermatrix :: String
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["input-m-modes"], dict["input-transfer-matrix"],
           dict["output-m-modes"], dict["output-transfer-matrix"])
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    propagate_flags(project, config)
    Project.touch(project, config.output_mmodes)
end

function propagate_flags(project, config)
    path = Project.workspace(project)
    flag = BPJSpec.propagate_flags

    mmodes         = BPJSpec.load(joinpath(path, config.input_mmodes))
    transfermatrix = BPJSpec.load(joinpath(path, config.input_transfermatrix))
    mmodes_storage         = MultipleFiles(joinpath(path, config.output_mmodes))
    transfermatrix_storage = MultipleFiles(joinpath(path, config.output_transfermatrix))

    mmodes′, transfermatrix′ = flag(mmodes, transfermatrix,
                                    mmodes_storage=mmodes_storage,
                                    transfermatrix_storage=transfermatrix_storage,
                                    progress=true)
end

end

