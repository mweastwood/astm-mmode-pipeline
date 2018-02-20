module Driver

using BPJSpec
using Unitful

include("../lib/Common.jl"); using .Common

function covariances(spw, name)
    path = getdir(spw, name)

    transfermatrix  = HierarchicalTransferMatrix(joinpath(path, "transfer-matrix"))
    transfermatrix′ = TransferMatrix(joinpath(path, "transfer-matrix-averaged"))
    lmax = transfermatrix.lmax
    mmax = transfermatrix.mmax
    frequencies = transfermatrix′.frequencies
    bandwidth   = transfermatrix′.bandwidth
    hierarchy   = transfermatrix.hierarchy

    signal   = AngularCovarianceMatrix(joinpath(path, "covariance-matrix-fiducial-signal"),
                                       lmax, frequencies, bandwidth,
                                       BPJSpec.fiducial_signal_model(),
                                       progressbar=true)
end

end

