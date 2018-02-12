module Driver

using BPJSpec
using FileIO, JLD2

include("../lib/Common.jl"); using .Common

function fisher(spw, name)
    path  = getdir(spw, name)
    path′ = joinpath(path, "basis-covariance-matrices")

    file = joinpath(path, "transfer-matrix-averaged")
    transfermatrix = BPJSpec.SpectralBlockDiagonalMatrix(file)

    model = load(joinpath(path′, "FIDUCIAL.jld2"), "model")
    covariancematrices = BPJSpec.AngularCovarianceMatrix[]
    for j = 1:length(model.kperp), i = 1:length(model.kpara)
        file = joinpath(path′, @sprintf("%03d-%03d", i, j))
        covariancematrix = BPJSpec.AngularCovarianceMatrix(file)
        push!(covariancematrices, covariancematrix)
    end

    file = joinpath(path, "fisher-matrix")
    fishermatrix = BPJSpec.fisher(transfermatrix, covariancematrices)
end

end

