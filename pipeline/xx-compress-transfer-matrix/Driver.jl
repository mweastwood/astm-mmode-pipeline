module Driver

using BPJSpec

include("../lib/Common.jl"); using .Common

function compress(spw, name)
    path = getdir(spw, name)

    file = joinpath(path, "transfer-matrix")
    transfermatrix  = BPJSpec.HierarchicalTransferMatrix(file)

    file = joinpath(path, "transfer-matrix-compressed")
    transfermatrix′ = BPJSpec.lossless_compress(file, transfermatrix)

    file = joinpath(path, "transfer-matrix-averaged")
    transfermatrix″ = BPJSpec.average_channels(file, transfermatrix′, 4)
end

end

