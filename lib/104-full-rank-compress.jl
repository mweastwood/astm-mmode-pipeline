module Driver

using BPJSpec
using YAML

include("Project.jl")

struct Config
    input_mmodes :: String
    input_transfermatrix :: String
    input_noisematrix :: String
    output_mmodes :: String
    output_transfermatrix :: String
    output_noisematrix :: String
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["input-m-modes"], dict["input-transfer-matrix"], dict["input-noise-matrix"],
           dict["output-m-modes"], dict["output-transfer-matrix"], dict["output-noise-matrix"])
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    compress(project, config)
    Project.touch(project, config.output_mmodes)
end

function compress(project, config)
    path = Project.workspace(project)

    mmodes         = BPJSpec.load(joinpath(path, config.input_mmodes))
    transfermatrix = BPJSpec.load(joinpath(path, config.input_transfermatrix))
    noisematrix    = BPJSpec.load(joinpath(path, config.input_noisematrix))

    mmodes_storage         = MultipleFiles(joinpath(path, config.output_mmodes))
    transfermatrix_storage = MultipleFiles(joinpath(path, config.output_transfermatrix))
    noisematrix_storage    = MultipleFiles(joinpath(path, config.output_noisematrix))

    BPJSpec.full_rank_compress(mmodes, transfermatrix, noisematrix,
                               mmodes_storage=mmodes_storage,
                               transfermatrix_storage=transfermatrix_storage,
                               noisematrix_storage=noisematrix_storage,
                               progress=true)
end

end

