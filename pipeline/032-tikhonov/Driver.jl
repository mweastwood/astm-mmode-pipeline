module Driver

using BPJSpec
using JLD2
using LibHealpix

include("../lib/Common.jl"); using .Common

function tikhonov(spw, name)
    path = getdir(spw, name)
    mmodes = MModes(joinpath(getdir(spw, name), "m-modes"))
    transfermatrix = HierarchicalTransferMatrix(joinpath(getdir(spw), "transfer-matrix"))
    alm = BPJSpec.tikhonov(transfermatrix, mmodes, 0.01) # TODO: adjustible tolerance
    jldopen(joinpath(path, "dirty-alm.jld2"), "w") do file
        file["alm"] = alm
    end
    # create a Healpix map
    _alm = Alm(Complex128, alm.lmax, alm.mmax)
    for m = 1:alm.lmax, l = m:alm.mmax
        @lm _alm[l, m] = alm[l, m]
    end
    map = alm2map(_alm, 2048)
    writehealpix(joinpath(path, "dirty-map.fits"), map, replace=true)
end

end

