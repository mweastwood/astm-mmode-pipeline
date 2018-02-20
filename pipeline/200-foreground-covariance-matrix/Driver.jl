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
end

end

