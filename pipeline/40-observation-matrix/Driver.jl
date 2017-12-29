module Driver

using BPJSpec
using JLD2
using ProgressMeter

include("../lib/Common.jl"); using .Common

function observation_matrix(spw, name)
    mmodes = MModes(joinpath(getdir(spw, name), "m-modes"))
    transfermatrix = HierarchicalTransferMatrix(joinpath(getdir(spw), "transfer-matrix"))
    jldopen(joinpath(getdir(spw, name), "observation-matrix.jld2"), "w") do file
        compute(file, transfermatrix, mmodes)
    end
end

function compute(file, transfermatrix, mmodes)
    lmax = BPJSpec.getlmax(transfermatrix)
    mmax = lmax

    pool  = CachingPool(workers())
    queue = collect(0:mmax)

    lck = ReentrantLock()
    prg = Progress(length(queue))
    increment() = (lock(lck); next!(prg); unlock(lck))

    @sync for worker in workers()
        @async while length(queue) > 0
            m = shift!(queue)
            block, cholesky = remotecall_fetch(_compute, pool, transfermatrix, mmodes, lmax, m)
            file[o6d(m)*"-block"]    = block
            file[o6d(m)*"-cholesky"] = cholesky
            increment()
        end
    end
end

function _compute(transfermatrix, mmodes, lmax, m)
    BLAS.set_num_threads(16)
    BB = zeros(Complex128, lmax-m+1, lmax-m+1)
    permutation = BPJSpec.baseline_permutation(transfermatrix, m)
    for ν in mmodes.metadata.frequencies
        _compute_accumulate!(BB, transfermatrix[m, ν], mmodes[m, ν], permutation)
    end
    BB, chol(BB + 0.01I) # TODO: adjustible tolerance
end

function _compute_accumulate!(BB, B, v, permutation)
    v = v[permutation]
    f = v .== 0 # flags
    B = B[.!f, :]
    B′ = B'
    BB .+= B′*B
end

end

