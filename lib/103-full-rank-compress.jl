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

    input_mmodes         = BPJSpec.load(joinpath(path, config.input_mmodes))
    input_transfermatrix = BPJSpec.load(joinpath(path, config.input_transfermatrix))
    input_noisematrix    = BPJSpec.load(joinpath(path, config.input_noisematrix))

    output_mmodes         = similar(input_mmodes,
                                    MultipleFiles(joinpath(path, config.output_mmodes)))
    output_transfermatrix = similar(input_transfermatrix,
                                    MultipleFiles(joinpath(path, config.output_transfermatrix)))
    output_noisematrix    = similar(input_transfermatrix, # note this is no longer diagonal
                                    MultipleFiles(joinpath(path, config.output_noisematrix)))

    BPJSpec.full_rank_compress!(output_mmodes, output_transfermatrix, output_noisematrix,
                                input_mmodes,  input_transfermatrix,  input_noisematrix,
                                progress=true)
end

end

