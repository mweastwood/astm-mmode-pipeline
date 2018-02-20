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

    points   = AngularCovarianceMatrix(joinpath(path, "covariance-matrix-point-sources"),
                                       lmax, frequencies, bandwidth,
                                       BPJSpec.extragalactic_point_sources(),
                                       progressbar=true)
    galactic = AngularCovarianceMatrix(joinpath(path, "covariance-matrix-galactic"),
                                       lmax, frequencies, bandwidth,
                                       BPJSpec.galactic_synchrotron(),
                                       progressbar=true)
    foregrounds = AngularCovarianceMatrix(joinpath(path, "covariance-matrix-fiducial-foregrounds"),
                                          lmax, frequencies, bandwidth,
                                          BPJSpec.NoComponent(),
                                          progressbar=true, compute=false)
    for l = 0:lmax
        foregrounds[l, 0] = points[l, 0] + galactic[l, 0]
    end

    signal   = AngularCovarianceMatrix(joinpath(path, "covariance-matrix-fiducial-signal"),
                                       lmax, frequencies, bandwidth,
                                       BPJSpec.fiducial_signal_model(),
                                       progressbar=true)
end

end

