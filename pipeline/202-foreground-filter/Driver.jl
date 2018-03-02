module Driver

using BPJSpec
using FileIO, JLD2

include("../lib/Common.jl"); using .Common

function foreground_filter(spw, name)
    path  = getdir(spw, name)

    file = joinpath(path, "transfer-matrix-compressed")
    transfermatrix = TransferMatrix(file)

    file = joinpath(path, "covariance-matrix-noise-compressed")
    noisematrix = DenseSpectralBlockDiagonalMatrix(file)

    file = joinpath(path, "covariance-matrix-fiducial-foregrounds")
    foregroundmatrix = AngularCovarianceMatrix(file)

    file = joinpath(path, "covariance-matrix-fiducial-signal")
    signalmatrix = AngularCovarianceMatrix(file)

    BPJSpec.kltransforms(transfermatrix, noisematrix, foregroundmatrix, signalmatrix;
                         threshold=0.1)
end

end

