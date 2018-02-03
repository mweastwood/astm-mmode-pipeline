module Driver

using BPJSpec

include("../lib/Common.jl"); using .Common

function compress(spw, name)
    path = getdir(spw, name)

    file = joinpath(path, "transfer-matrix")
    transfermatrix  = BPJSpec.HierarchicalTransferMatrix(file)

    file = joinpath(path, "transfer-matrix-compressed")
    transfermatrix′ = BPJSpec.lossless_compress(file, transfermatrix)

    # According to this calculation, averaging 10 channels should limit us to k < 1.0 Mpc^-1, which is fine
    # julia> 2π/(BPJSpec.comoving_distance(BPJSpec.redshift(70.000u"MHz")) - BPJSpec.comoving_distance(BPJSpec.redshift(70.240u"MHz")))
    # 1.0273400427793544 Mpc^-1
    file = joinpath(path, "transfer-matrix-averaged")
    transfermatrix″ = BPJSpec.average_channels(file, transfermatrix′, 10)
end

end

