module Driver

using BPJSpec
using JLD2

include("../lib/Common.jl"); using .Common

function tikhonov(spw, name)
    path = getdir(spw, name)
    mmodes = MModes(joinpath(getdir(spw, name), "m-modes"))
    transfermatrix = HierarchicalTransferMatrix(joinpath(getdir(spw), "transfer-matrix"))
    alm = BPJSpec.tikhonov(transfermatrix, mmodes, 0.01)
    jldopen(joinpath(path, "dirty-alm.jld2"), "w") do file
        file["alm"] = alm
    end
end

end

