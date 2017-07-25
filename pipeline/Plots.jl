# Generate data needed for making plots in the paper.
module Plots

using Pipeline
using JLD
using LibHealpix
using CasaCore.Measures

"Create an image of the psf."
function psf_image()
    spw = 4
    str = @sprintf("spw%02d", spw)
    dataset = "rainy"
    dir = Pipeline.Common.getdir(spw)
    observation_matrix, lmax, mmax = load(joinpath(dir, "observation-matrix-$dataset.jld"),
                                          "blocks", "lmax", "mmax")
    nside = 2048

    direction = Direction(dir"ITRF", 0degrees, 45degrees)
    θ = π/2 - latitude(direction)
    ϕ = longitude(direction)
    alm = Pipeline.Cleaning.getpsf_alm(observation_matrix, θ, ϕ, lmax, mmax)
    map = alm2map(alm, nside)
    img = Pipeline.Cleaning.postage_stamp(map, direction)
    save(joinpath(dir, "tmp", "$str-psf-45-degrees.jld"), "img", img)

    direction = Direction(dir"ITRF", 0degrees, 0degrees)
    θ = π/2 - latitude(direction)
    ϕ = longitude(direction)
    alm = Pipeline.Cleaning.getpsf_alm(observation_matrix, θ, ϕ, lmax, mmax)
    map = alm2map(alm, nside)
    img = Pipeline.Cleaning.postage_stamp(map, direction)
    save(joinpath(dir, "tmp", "$str-psf-00-degrees.jld"), "img", img)

end



end

