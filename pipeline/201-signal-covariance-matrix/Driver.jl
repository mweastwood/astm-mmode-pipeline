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

    signal = AngularCovarianceMatrix(joinpath(path, "covariance-matrix-fiducial-signal"),
                                     lmax, frequencies, bandwidth,
                                     fiducial_signal_model(),
                                     progressbar=true)
end

function fiducial_signal_model()
    kpara = logspace(log10(0.01), log10(1.0), 200) .* u"Mpc^-1"
    kperp = logspace(log10(0.01), log10(1.0), 200) .* u"Mpc^-1"
    unshift!(kpara, 0u"Mpc^-1")
    unshift!(kperp, 0u"Mpc^-1")
    k = sqrt.(kpara.^2 .+ kperp.'.^2)
    Δ21 = min.(40 .* (k./(0.03u"Mpc^-1")).^2, 400) .* u"mK^2"
    P21 = Δ21 .* 2π^2 ./ (k+0.05u"Mpc^-1").^3
    BPJSpec.SignalModel((10., 30.), kpara, kperp, P21)
end

end

