module Driver

using BPJSpec
using FileIO, JLD2
using YAML

include("Project.jl")

struct Config
    input_basis            :: String
    input_mmodes1          :: String
    input_mmodes2          :: String
    input_transfermatrix   :: String
    input_covariancematrix :: String
    input_fishermatrix     :: String
    output                 :: String
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["input-basis"],
           dict["input-m-modes-1"],
           dict["input-m-modes-2"],
           dict["input-transfer-matrix"],
           dict["input-covariance-matrix"],
           dict["input-fisher-matrix"],
           dict["output"])
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    fisher(project, config)
end

function fisher(project, config)
    path  = Project.workspace(project)
    path′ = joinpath(path, config.input_basis)

    mmodes1          = BPJSpec.load(joinpath(path, config.input_mmodes1))
    mmodes2          = BPJSpec.load(joinpath(path, config.input_mmodes2))
    transfermatrix   = BPJSpec.load(joinpath(path, config.input_transfermatrix))
    covariancematrix = BPJSpec.load(joinpath(path, config.input_covariancematrix))

    mmodes = similar(mmodes1)
    difference_and_scale(x, y) = (x - y)/√2
    @. mmodes = difference_and_scale(mmodes1, mmodes2)

    basis, model = FileIO.load(joinpath(path, config.input_basis*".jld2"),
                               "covariance-matrices", "model")

    F, b = FileIO.load(joinpath(path, config.input_fishermatrix*".jld2"),
                       "fisher-information", "noise-bias")
    q = q_estimator(mmodes, transfermatrix, covariancematrix, basis)

    minvariance_M⁻¹ = BPJSpec.inverse_mixing_matrix(F, strategy=:minvariance)
    minvariance_W   = BPJSpec.window_functions(F, minvariance_M⁻¹)
    minvariance_Σ   = BPJSpec.windowed_covariance(F, minvariance_M⁻¹)
    minvariance_p   = minvariance_M⁻¹\(q-b)

    save(joinpath(path, config.output*".jld2"),
         "signal-model", model, "fisher-information", F, "noise-bias", b, "q", q,
         "minvariance-inverse-mixing-matrix",   minvariance_M⁻¹,
         "minvariance-window-functions",   minvariance_W,
         "minvariance-covariance",   minvariance_Σ,
         "minvariance-p",   minvariance_p)
end

end

