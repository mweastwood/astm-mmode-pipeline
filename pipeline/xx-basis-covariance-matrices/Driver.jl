module Driver

using BPJSpec
using FileIO, JLD2
using Unitful, UnitfulAstro

include("../lib/Common.jl"); using .Common

function covariance(spw, name)
    path  = getdir(spw, name)
    path′ = joinpath(path, "basis-covariance-matrices")
    isdir(path′) || mkdir(path′)
    model = fiducial()

    file = joinpath(path, "transfer-matrix-averaged")
    transfermatrix = BPJSpec.SpectralBlockDiagonalMatrix(file)
    lmax = transfermatrix.mmax
    frequencies = transfermatrix.frequencies

    for j = 1:length(model.kperp), i = 1:length(model.kpara)
        model.power[i, j] = 1e10u"K^2*Mpc^3"
        file = joinpath(path′, @sprintf("%03d-%03d", i, j))
        matrix = BPJSpec.AngularCovarianceMatrix(file, lmax, frequencies, model)
        BPJSpec.compute!(matrix)
        model.power[i, j] = 0.0u"K^2*Mpc^3"
    end

    save(joinpath(path′, "FIDUCIAL.jld2"), "model", model)
end

function fiducial()
    # logarithmic bins (but include 0 Mpc⁻¹)
    kpara = logspace(-4, +0, 10).*u"Mpc^-1"
    kperp = logspace(-4, -1, 11).*u"Mpc^-1"
    unshift!(kpara, 0u"Mpc^-1")
    unshift!(kperp, 0u"Mpc^-1")
    power = zeros(length(kpara), length(kperp)) .* u"K^2*Mpc^3"
    BPJSpec.SignalModel(kpara, kperp, power)
end

end

