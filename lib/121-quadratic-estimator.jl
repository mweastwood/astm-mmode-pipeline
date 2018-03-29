module Driver

using BPJSpec
using FileIO, JLD2
using YAML

include("Project.jl")

struct Config
    input_basis            :: String
    input_mmodes           :: String
    input_transfermatrix   :: String
    input_covariancematrix :: String
    output                 :: String
    iterations             :: Int
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["input-basis"],
           dict["input-m-modes"],
           dict["input-transfer-matrix"],
           dict["input-covariance-matrix"],
           dict["output"],
           dict["iterations"])
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    fisher(project, config)
end

function fisher(project, config)
    path  = Project.workspace(project)
    path′ = joinpath(path, config.input_basis)

    mmodes           = BPJSpec.load(joinpath(path, config.input_mmodes))
    transfermatrix   = BPJSpec.load(joinpath(path, config.input_transfermatrix))
    covariancematrix = BPJSpec.load(joinpath(path, config.input_covariancematrix))

    model = FileIO.load(joinpath(path′, "FIDUCIAL.jld2"), "model")
    basis = [BPJSpec.load(joinpath(path′, @sprintf("%03d", idx))) for idx = 1:length(model.power)]

    F = fisher_information(transfermatrix, covariancematrix, basis, iterations=config.iterations)
    b = noise_bias(transfermatrix, covariancematrix, basis, iterations=config.iterations)
    q = q_estimator(mmodes, transfermatrix, covariancematrix, basis)

    M⁻¹ = BPJSpec.inverse_mixing_matrix(F, strategy=:uncorrelated)
    W   = BPJSpec.window_functions(F, M⁻¹)
    Σ   = BPJSpec.windowed_covariance(F, M⁻¹)
    σ   = sqrt.(diag(Σ))
    p   = M⁻¹\(q-b)

    save(joinpath(path, config.output*".jld2"),
         "21-cm-signal-model", model,
         "fisher-information", F,
         "inverse-mixing-matrix", M⁻¹,
         "window-functions", W,
         "standard-errors", σ,
         "noise-bias", b,
         "q", q,
         "p", p)
end

end

