module Driver

using JLD
using ProgressMeter
using BPJSpec

include("../Pipeline.jl")

function go()
    spw = 14
    dir = Pipeline.Common.getdir(spw)
    times, flags, xx_rfi, yy_rfi, xx_rfi_flux, yy_rfi_flux =
        load(joinpath(dir, "rfi-subtracted-peeled-rainy-visibilities.jld"),
             "times", "flags", "xx-rfi", "yy-rfi", "xx-rfi-flux", "yy-rfi-flux")
    Nrfi = size(xx_rfi_flux)[1]
    for s = 1:Nrfi
        @show s
        norm_B, norm_v, norm_Bv = compute_shit(spw, times, flags, xx_rfi, yy_rfi,
                                               xx_rfi_flux, yy_rfi_flux, s)
        save(joinpath(dir, "tmp", "rfi-norms-$s.jld"),
             "norm_B", norm_B, "norm_v", norm_v, "norm_Bv", norm_Bv)
    end
end

function compute_shit(spw, times, flags, xx_rfi, yy_rfi, xx_rfi_flux, yy_rfi_flux, s)
    @time data = get_visibilities(xx_rfi, yy_rfi, xx_rfi_flux, yy_rfi_flux, s)
    @time folded, folded_flags = Pipeline.MModes._fold(spw, data, flags, "rfi", "")
    @time mmodes, mmodes_flags = Pipeline.MModes.getmmodes_internal(folded, folded_flags)
    transfermatrix = TransferMatrix(joinpath(Pipeline.Common.getdir(spw), "transfermatrix"))
    norm_B, norm_v, norm_Bv = _compute_shit(transfermatrix, mmodes, mmodes_flags)
end

function _compute_shit(transfermatrix, mmodes, mmode_flags)
    # We want to compute ||B||, ||v||, and ||B^*v||.
    N = transfermatrix.mmax+1
    prg = Progress(N)
    norm_B = zeros(N)
    norm_v = zeros(N)
    norm_Bv = zeros(N)
    for m = 0:transfermatrix.mmax
        idx = m+1
        B = transfermatrix[m, 1]
        v = mmodes[idx]
        f = mmode_flags[idx]
        norm_B[idx], norm_v[idx], norm_Bv[idx] = do_the_compute_shit(B, v, f)
        next!(prg)
    end
    norm_B, norm_v, norm_Bv
end

function do_the_compute_shit(B, v, f)
    B = B[!f, :]
    v = v[!f]
    norm(B), norm(v), norm(B'*v)
end

function get_visibilities(xx_rfi, yy_rfi, xx_rfi_flux, yy_rfi_flux, s)
    Nrfi, Ntime = size(xx_rfi_flux)
    Nbase = size(xx_rfi, 1)
    data = zeros(Complex128, 2, Nbase, Ntime)
    for idx = 1:Ntime, α = 1:Nbase
        data[1, α, idx] += xx_rfi_flux[s, idx]*xx_rfi[α, s]
        data[2, α, idx] += yy_rfi_flux[s, idx]*yy_rfi[α, s]
    end
    data
end

end

