module Driver

using BPJSpec

include("../lib/Common.jl"); using .Common

function average(spw, name)
    path = getdir(spw, name)
    file = joinpath(path, "transfer-matrix")
    transfermatrix  = HierarchicalTransferMatrix(file)
    transfermatrix′ = BPJSpec.average_frequency_channels(transfermatrix, 10)
end

end

