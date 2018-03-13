module Driver

using BPJSpec
using YAML

include("Project.jl")

# TODO: split up this monstrosity into constituent parts

struct Config
    input_mmodes :: String
    input_transfermatrix :: String
    input_noisematrix :: String
    input_foregroundmatrix :: String
    input_signalmatrix :: String
    output_observed_foregroundmatrix :: String
    output_observed_signalmatrix :: String
    output_foreground_filter :: String
    output_filtered_signalmatrix :: String
    output_filtered_noisematrix :: String
    output_whitening_matrix :: String
    output_mmodes :: String
    output_transfermatrix :: String
    output_covariancematrix :: String
    threshold :: Float64
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["input-m-modes"], dict["input-transfer-matrix"], dict["input-noise-matrix"],
           dict["input-foreground-matrix"], dict["input-signal-matrix"],
           dict["output-observed-foreground-matrix"], dict["output-observed-signal-matrix"],
           dict["output-foreground-filter"],
           dict["output-filtered-signal-matrix"], dict["output-filtered-noise-matrix"],
           dict["output-whitening-matrix"],
           dict["output-m-modes"], dict["output-transfer-matrix"],
           dict["output-covariance-matrix"], dict["threshold"])
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    foreground_filter(project, config)
    Project.touch(project, config.output_mmodes)
end

function foreground_filter(project, config)
    path = Project.workspace(project)

    mmodes           = BPJSpec.load(joinpath(path, config.input_mmodes))
    transfermatrix   = BPJSpec.load(joinpath(path, config.input_transfermatrix))
    noisematrix      = BPJSpec.load(joinpath(path, config.input_noisematrix))
    foregroundmatrix = BPJSpec.load(joinpath(path, config.input_foregroundmatrix))
    signalmatrix     = BPJSpec.load(joinpath(path, config.input_signalmatrix))

    MF = MultipleFiles # for brevity
    j  = joinpath      # for brefity as well
    observed_foregroundmatrix_storage = MF(j(path, config.output_observed_foregroundmatrix))
    observed_signalmatrix_storage     = MF(j(path, config.output_observed_signalmatrix))
    foreground_filter_storage         = MF(j(path, config.output_foreground_filter))
    filtered_signalmatrix_storage     = MF(j(path, config.output_filtered_signalmatrix))
    filtered_noisematrix_storage      = MF(j(path, config.output_filtered_noisematrix))
    whitening_matrix_storage          = MF(j(path, config.output_whitening_matrix))
    mmodes_storage                    = MF(j(path, config.output_mmodes))
    transfermatrix_storage            = MF(j(path, config.output_transfermatrix))
    covariancematrix_storage          = MF(j(path, config.output_covariancematrix))

    BPJSpec.kltransforms(mmodes, transfermatrix, noisematrix, foregroundmatrix, signalmatrix,
                         observed_foregroundmatrix_storage, observed_signalmatrix_storage,
                         foreground_filter_storage,
                         filtered_signalmatrix_storage, filtered_noisematrix_storage,
                         whitening_matrix_storage,
                         mmodes_storage, transfermatrix_storage, covariancematrix_storage,
                         threshold=config.threshold)
end

end

