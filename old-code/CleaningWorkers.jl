module CleaningWorkers

export give_responsibilities
export load_transfermatrix, load_mmodes
export run_tikhonov, run_observe

using BPJSpec

const lmax = 1000
const mmax = 1000
const mmode_dir = "workspace/mmodes-cleaned"
const transfermatrix_dir = "workspace/transfermatrix"

const responsibilities = Int[] # list of m values that the worker is responsible for
const transfermatrix_blocks = Matrix{Complex128}[]
const mmode_blocks = Vector{Complex128}[]
const alm_blocks = Vector{Complex128}[]

function give_responsibilities(myresponsibilities)
    empty!(responsibilities)
    append!(responsibilities, myresponsibilities)
end

function load_transfermatrix()
    isempty(transfermatrix_blocks) || return
    transfermatrix = TransferMatrix(transfermatrix_dir)
    for m in responsibilities
        push!(transfermatrix_blocks, transfermatrix[m,1])
    end
end

function load_mmodes()
    isempty(mmode_blocks) || return
    mmodes = MModes(mmode_dir)
    for m in responsibilities
        push!(mmode_blocks, mmodes[m,1])
    end
end

function run_tikhonov()
    empty!(alm_blocks)
    for idx = 1:length(responsibilities)
        m = responsibilities[idx]
        A = transfermatrix_blocks[idx]
        b = mmode_blocks[idx]
        BPJSpec.account_for_flags!(A, b)
        x = tikhonov(A, b, 0.05)
        push!(alm_blocks, x)
    end
    alm_blocks
end

"""
    run_observe(flux, θ, ϕ)

Observe and image the sources located at `(θ, ϕ)` with
the given flux.
"""
function run_observe(flux, θ, ϕ)
    N = length(flux)
    empty!(alm_blocks)
    for idx = 1:length(responsibilities)
        m = responsibilities[idx]
        x = zeros(Complex128, lmax-m+1)
        for l = m:lmax
            for jdx = 1:N
                x[l-m+1] += flux[jdx]*conj(BPJSpec.Y(l, m, θ[jdx], ϕ[jdx]))
            end
        end
        A = transfermatrix_blocks[idx]
        BPJSpec.account_for_flags!(A, mmode_blocks[idx])
        b = A*x
        x = tikhonov(A, b, 0.05)
        push!(alm_blocks, x)
    end
    alm_blocks
end

end

