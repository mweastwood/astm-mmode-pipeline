module Driver

using BPJSpec
using YAML

include("Project.jl")

struct Config
    lhs_mmodes :: String
    rhs_mmodes :: String
    lhs_transfermatrix :: String
    rhs_transfermatrix :: String
    lhs_covariance :: String
    rhs_covariance :: String
    output_mmodes :: String
    output_transfermatrix :: String
    output_covariance :: String
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["lhs-m-modes"],
           dict["rhs-m-modes"],
           dict["lhs-transfer-matrix"],
           dict["rhs-transfer-matrix"],
           dict["lhs-covariance-matrix"],
           dict["rhs-covariance-matrix"],
           dict["output-m-modes"],
           dict["output-transfer-matrix"],
           dict["output-covariance-matrix"])
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    difference(project, config)
end

function difference(project, config)
    # The m-modes that we are differencing have already had their noise whitened, so we would like
    # to difference them in a way such that the noise remains white.

    path  = Project.workspace(project)

    lhs_mmodes           = BPJSpec.load(joinpath(path, config.lhs_mmodes))
    lhs_transfermatrix   = BPJSpec.load(joinpath(path, config.lhs_transfermatrix))
    lhs_covariance       = BPJSpec.load(joinpath(path, config.lhs_covariance))
    rhs_mmodes           = BPJSpec.load(joinpath(path, config.rhs_mmodes))
    rhs_transfermatrix   = BPJSpec.load(joinpath(path, config.rhs_transfermatrix))
    rhs_covariance       = BPJSpec.load(joinpath(path, config.rhs_covariance))

    function c(T, name)
        ProgressBar(create(T, MultipleFiles(joinpath(path, name)), lhs_mmodes.mmax))
    end

    output_mmodes            = c(MBlockVector, config.output_mmodes)
    output_transfermatrix    = c(MBlockMatrix, config.output_transfermatrix)
    output_covariance        = c(MBlockMatrix, config.output_covariance)


    # The m-modes will be differenced and normalized by √2 such that the thermal noise remains
    # unchanged.
    diff(lhs, rhs) = (lhs - rhs)/√2
    @. output_mmodes = diff(lhs_mmodes, rhs_mmodes)

    # The transfer matrices should be the same, but we'll average them together and scale by the
    # same amount as the m-modes.
    avg(lhs, rhs) = (lhs + rhs)/2
    scale(block) = block/√2
    @. output_transfermatrix = scale(avg(lhs_transfermatrix, rhs_transfermatrix))

    # The covariance matrices should also be the same and remain unscaled. So we'll just average
    # them together.
    @. output_covariance = avg(lhs_covariance, rhs_covariance)
end

end

