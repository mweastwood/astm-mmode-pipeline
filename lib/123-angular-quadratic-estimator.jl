# Estimating the angular power-spectrum with a quadratic estimator is a little easier because the
# angular covariance matrices are *much* simpler, so we can simplify a lot of the computation.

module Driver

using BPJSpec
using ProgressMeter
using YAML

function angular_quadratic_estimator(transfermatrix, mmodes)
    #mmodes         = BPJSpec.load(joinpath(path, config.mmodes))
    #transfermatrix = BPJSpec.load(joinpath(path, config.transfermatrix))

    mmax  = transfermatrix.mmax
    Nfreq = length(transfermatrix.frequencies)
    F = Array{Matrix{Float64}}(mmax+1, Nfreq)
    q = Array{Vector{Float64}}(mmax+1, Nfreq)

    #queue = collect(BPJSpec.indices(transfermatrix))
    queue = reshape(collect(Iterators.product(0:mmax, 1:1)), mmax+1)
    @show queue
    lck = ReentrantLock()
    prg = Progress(length(queue))
    increment() = (lock(lck); next!(prg); unlock(lck))

    @sync for worker in workers()
        @async while length(queue) > 0
            m, β = shift!(queue)
            F′, q′ = remotecall_fetch(compute_F_q, worker, transfermatrix, mmodes, m, β)
            F[m+1, β] = F′
            q[m+1, β] = q′
            increment()
        end
    end

    F, q
end


function compute_F_q(transfermatrix, mmodes, m, β)
    B = transfermatrix[m, β]
    v = mmodes[m, β]
    lmax = transfermatrix.mmax
    F = zeros(lmax + 1, lmax + 1)
    q = zeros(lmax + 1)
    _compute_F_q!(F, q, B, v, lmax, m)
end

function _compute_F_q!(F, q, B, v, lmax, m)
    Bv = B'*v
    for l = m:lmax
        idx1 = l - m + 1
        jdx1 = l + 1
        col1 = @view B[:, idx1]
        q[jdx1] = abs2(Bv[idx1])
        F[jdx1, jdx1] = abs2(dot(col1, col1))
        for l′ = l+1:lmax
            idx2 = l′ - m + 1
            jdx2 = l′ + 1
            col2 = @view B[:, idx2]
            F[jdx1, jdx2] = abs2(dot(col1, col2))
            F[jdx2, jdx1] = F[jdx1, jdx2]
        end 
    end
    F, q
end

end

