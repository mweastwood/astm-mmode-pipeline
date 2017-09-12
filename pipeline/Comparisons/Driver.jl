module Driver

include("../Pipeline.jl")

using PyPlot
using JLD
using LibHealpix
using CasaCore.Measures
using TTCal
using BPJSpec
using NLopt
using LsqFit
using FITSIO
using ProgressMeter

const workspace = joinpath(dirname(@__FILE__), "..", "..", "workspace")

include("guzman.jl")
include("haslam.jl")
include("internal.jl")

#function compare_with_haslam()
#    haslam = readhealpix(joinpath(workspace, "comparison-maps", "haslam408_dsds_Remazeilles2014.fits"))
#    haslam_freq = 408e6
#
#    # There's a type instability in here somewhere because loading from disk makes the power law
#    # fitting code way faster.
#
#    #lwa = HealpixMap[]
#    #for spw = 4:2:18
#    #    @show spw
#    #    ν = Pipeline.Common.getfreq(spw)
#    #    dir = Pipeline.Common.getdir(spw)
#    #    map = readhealpix(joinpath(dir, "map-wiener-filtered-rainy-2048-galactic.fits"))
#    #    map = smooth(map, 56/60, nside(haslam))
#    #    map = map * (BPJSpec.Jy * (BPJSpec.c/ν)^2 / (2*BPJSpec.k))
#    #    push!(lwa, map)
#    #    writehealpix("tmp/$spw.fits", map, replace=true)
#    #end
#    lwa = HealpixMap[readhealpix("tmp/$spw.fits") for spw = 4:2:18]
#    lwa_freq = Float64[Pipeline.Common.getfreq(spw) for spw = 4:2:18]
#
#    # Fit a power law to each pixel
#    ν = [lwa_freq; haslam_freq]
#    maps = [lwa; haslam]
#
#    N = length(haslam)
#    flags = zeros(Bool, N)
#    spectral_index = zeros(N)
#
#    A = [log10(ν/70e6) ones(length(ν))]
#    prg = Progress(N)
#    for pixel = 1:N
#        y = [map[pixel] for map in maps]
#        keep = y .> 0
#        if sum(keep) ≥ 2
#            line = A[keep, :]\log10(y[keep])
#            spectral_index[pixel] = line[1]
#        else
#            flags[pixel] = true
#        end
#        next!(prg)
#    end
#
#    index_map = HealpixMap(spectral_index)
#    img = mollweide(index_map)
#
#    #figure(1); clf()
#    #writehealpix("index_map.fits", index_map, replace=true)
#    #index_map = readhealpix("index_map.fits")
#    #imshow(mollweide(index_map), vmin=-2.8, vmax=-2.2, cmap=get_cmap("RdBu"))
#    #colorbar()
#
#    save(joinpath("../workspace/comparison-with-haslam.jld"), "index", img)
#end

function smooth(map, width, output_nside=nside(map))
    # spherical convolution: https://www.cs.jhu.edu/~misha/Spring15/17.pdf
    σ = width/(2sqrt(2log(2)))
    kernel = HealpixMap(Float64, output_nside)
    for pix = 1:length(kernel)
        θ, ϕ = LibHealpix.pix2ang_ring(nside(kernel), pix)
        θ = rad2deg(θ)
        kernel[pix] = exp(-θ^2/(2σ^2))
    end
    dΩ = 4π/length(kernel)
    kernel = HealpixMap(kernel.pixels / (sum(kernel.pixels)*dΩ))

    lmax = mmax = 1000
    map_alm = map2alm(map, lmax, mmax, iterations=10)
    kernel_alm = map2alm(kernel, lmax, mmax, iterations=10)
    output_alm = Alm(Complex128, lmax, mmax)
    for m = 0:mmax, l = m:lmax
        output_alm[l, m] = sqrt((4π)/(2l+1))*map_alm[l, m]*kernel_alm[l, 0]
    end

    alm2map(output_alm, output_nside)
end

"degrade the map to a lower nside so that adjacent pixels aren't correlated anymore"
function degrade(map, new_nside)
    new_npix = nside2npix(new_nside)
    output = zeros(new_npix)
    normalization = zeros(Int, new_npix)
    for idx = 1:length(map)
        vec = LibHealpix.pix2vec_ring(nside(map), idx)
        jdx = LibHealpix.vec2pix_ring(new_nside, vec)
        output[jdx] += map[idx]
        normalization[jdx] += 1
    end
    HealpixMap(output ./ normalization)
end

end

