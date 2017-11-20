module Driver

include("../Pipeline.jl")

#using PyPlot
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

include("lwa1.jl")
include("drao.jl")
include("guzman.jl")
include("haslam.jl")
include("internal.jl")

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

