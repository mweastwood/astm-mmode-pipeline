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

    unwindowed_M⁻¹ = BPJSpec.inverse_mixing_matrix(F, strategy=:unwindowed)
    unwindowed_W   = BPJSpec.window_functions(F, M⁻¹)
    unwindowed_Σ   = BPJSpec.windowed_covariance(F, M⁻¹)
    unwindowed_p   = M⁻¹\(q-b)

    minvariance_M⁻¹ = BPJSpec.inverse_mixing_matrix(F, strategy=:minvariance)
    minvariance_W   = BPJSpec.window_functions(F, M⁻¹)
    minvariance_Σ   = BPJSpec.windowed_covariance(F, M⁻¹)
    minvariance_p   = M⁻¹\(q-b)

    uncorrelated_M⁻¹ = BPJSpec.inverse_mixing_matrix(F, strategy=:uncorrelated)
    uncorrelated_W   = BPJSpec.window_functions(F, M⁻¹)
    uncorrelated_Σ   = BPJSpec.windowed_covariance(F, M⁻¹)
    uncorrelated_p   = M⁻¹\(q-b)

    save(joinpath(path, config.output*".jld2"),
         "21-cm-signal-model", model, "fisher-information", F, "noise-bias", b, "q", q,
         "unwindowed-inverse-mixing-matrix",     unwindowed_M⁻¹,
         "minvariance-inverse-mixing-matrix",   minvariance_M⁻¹,
         "uncorrelated-inverse-mixing-matrix", uncorrelated_M⁻¹,
         "unwindowed-window-functions",     unwindowed_W,
         "minvariance-window-functions",   minvariance_W,
         "uncorrelated-window-functions", uncorrelated_W,
         "unwindowed-covariance",     unwindowed_Σ,
         "minvariance-covariance",   minvariance_Σ,
         "uncorrelated-covariance", uncorrelated_Σ,
         "unwindowed-p",     unwindowed_p,
         "minvariance-p",   minvariance_p,
         "uncorrelated-p", uncorrelated_p)
end

end

