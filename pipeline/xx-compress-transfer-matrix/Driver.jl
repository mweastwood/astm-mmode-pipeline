module Driver

using BPJSpec
using Unitful

include("../lib/Common.jl"); using .Common

function compress(spw, name)
    path = getdir(spw, name)

    transfermatrix = TransferMatrix(joinpath(path, "transfer-matrix-averaged"))
    noisematrix    = NoiseCovarianceMatrix(joinpath(path, "covariance-matrix-noise"))
    transfermatrix′, noisematrix′ = BPJSpec.full_rank_compress(transfermatrix, noisematrix)
end

end

