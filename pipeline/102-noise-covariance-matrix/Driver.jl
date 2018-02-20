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

    # This is nominally representative of the rainy day dataset
    #noisemodel = BPJSpec.NoiseModel(2000u"K", 13u"s", 7756)
    # This is nominally representative of some fiducial long integration
    noisemodel = BPJSpec.NoiseModel(2000u"K", 13u"s", 30*6628)
    noise = NoiseCovarianceMatrix(joinpath(path, "covariance-matrix-noise"),
                                  mmax, frequencies, bandwidth, hierarchy, noisemodel)
end

end

