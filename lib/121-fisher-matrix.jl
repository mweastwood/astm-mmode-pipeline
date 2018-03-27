module Driver

using BPJSpec
using FileIO, JLD2
using YAML

include("Project.jl")

struct Config
    input_basis :: String
    input_transfermatrix :: String
    input_covariancematrix :: String
    output :: String
    iterations :: Int
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["input-basis"], dict["input-transfer-matrix"],
           dict["input-covariance-matrix"], dict["output"], dict["iterations"])
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    fisher(project, config)
    Project.touch(project, config.output)
end

function fisher(project, config)
    path  = Project.workspace(project)
    path′ = joinpath(path, config.input_basis)

    transfermatrix   = BPJSpec.load(joinpath(path, config.input_transfermatrix))
    covariancematrix = BPJSpec.load(joinpath(path, config.input_covariancematrix))

    model = FileIO.load(joinpath(path′, "FIDUCIAL.jld2"), "model")
    basis = [BPJSpec.load(joinpath(path′, @sprintf("%03d", idx))) for idx = 1:length(model.power)]

    F = BPJSpec.fisher_information(transfermatrix, covariancematrix, basis,
                                   iterations=config.iterations)
    save(joinpath(path, config.output*".jld2"), "matrix", F, "model", model)
end

end

