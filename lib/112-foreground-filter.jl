module Driver

using BPJSpec
using YAML

include("Project.jl")

# TODO: split up this monstrosity into constituent parts

struct Config
    input_mmodes :: String
    input_transfermatrix :: String
    input_noisematrix :: String
    input_signalmatrix :: String
    input_foregroundmatrix :: String
    output_mmodes :: String
    output_transfermatrix :: String
    output_covariance :: String
    output_foreground_filter :: String
    output_noise_whitener :: String
    threshold :: Float64
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["input-m-modes"],
           dict["input-transfer-matrix"],
           dict["input-noise-matrix"],
           dict["input-signal-matrix"],
           dict["input-foreground-matrix"],
           dict["output-m-modes"],
           dict["output-transfer-matrix"],
           dict["output-covariance-matrix"],
           dict["output-foreground-filter"],
           dict["output-noise-whitener"],
           dict["threshold"])
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    foreground_filter(project, config)
end

function foreground_filter(project, config)
    path = Project.workspace(project)

    input_mmodes           = BPJSpec.load(joinpath(path, config.input_mmodes))
    input_transfermatrix   = BPJSpec.load(joinpath(path, config.input_transfermatrix))
    input_noisematrix      = BPJSpec.load(joinpath(path, config.input_noisematrix))
    input_signalmatrix     = BPJSpec.load(joinpath(path, config.input_signalmatrix))
    input_foregroundmatrix = BPJSpec.load(joinpath(path, config.input_foregroundmatrix))

    function c(T, name)
        create(T, MultipleFiles(joinpath(path, name)), input_mmodes.mmax)
    end

    output_mmodes            = c(MBlockVector, config.output_mmodes)
    output_transfermatrix    = c(MBlockMatrix, config.output_transfermatrix)
    output_covariance        = c(MBlockMatrix, config.output_covariance)
    output_foreground_filter = c(MBlockMatrix, config.output_foreground_filter)
    output_noise_whitener    = c(MBlockMatrix, config.output_noise_whitener)

    foreground_filter!(output_mmodes, output_transfermatrix, output_covariance,
                       output_foreground_filter, output_noise_whitener,
                       input_mmodes, input_transfermatrix, input_noisematrix,
                       input_signalmatrix, input_foregroundmatrix,
                       threshold=config.threshold, tempdir=joinpath(path, "tmp"), cleanup=true)
end

end

