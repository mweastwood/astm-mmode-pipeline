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
    for idx = 1:length(model.power)
        file = joinpath(path′, @sprintf("%03d", idx))
        basismatrix = AngularCovarianceMatrix(file)
        push!(basis, basismatrix)
    end

    F = BPJSpec.fisher_information(transfermatrix, covariancematrix, basis, iterations=100)
    save(joinpath(path, "fisher-matrix.jld2"), "matrix", F, "model", model)
end

end

