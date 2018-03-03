function singular_values(dataset)
    for spw = 4:2:18
        @show spw
        singular_values(spw, dataset)
    end
end

function singular_values(spw, dataset)
    dir = getdir(spw)
    transfermatrix = TransferMatrix(joinpath(dir, "transfermatrix"))
    σ = _singular_values(transfermatrix)
    save(joinpath(dir, "singular-values.jld"), "values", σ)
end

function _singular_values(transfermatrix)
    output = Vector{Float64}[]
    prg = Progress(transfermatrix.mmax+1)
    for m = 0:transfermatrix.mmax
        B = transfermatrix[m, 1]
        σ = svdvals(B)
        push!(output, σ)
        next!(prg)
    end
    output
end

