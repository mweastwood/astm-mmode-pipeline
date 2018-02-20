module Driver

using BPJSpec
using FileIO, JLD2

include("../lib/Common.jl"); using .Common

function fisher(spw, name)
    path  = getdir(spw, name)
    path′ = joinpath(path, "basis-covariance-matrices")

    file = joinpath(path, "transfer-matrix-final")
    transfermatrix = DenseBlockDiagonalMatrix(file)

    file = joinpath(path, "covariance-matrix-final")
    covariancematrix = DenseBlockDiagonalMatrix(file)

    model = load(joinpath(path′, "FIDUCIAL.jld2"), "model")
    basis = BPJSpec.AngularCovarianceMatrix[]
    for j = 1:length(model.kperp), i = 1:length(model.kpara)
        file = joinpath(path′, @sprintf("%03d-%03d", i, j))
        basismatrix = AngularCovarianceMatrix(file)
        push!(basis, basismatrix)
    end

    BPJSpec.fisher(transfermatrix, covariancematrix, basis, iterations=100)
end

end

