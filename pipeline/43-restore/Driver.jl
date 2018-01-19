module Driver

using JLD2
using LibHealpix
using ProgressMeter
using StaticArrays

include("../lib/Common.jl");   using .Common
include("../lib/Cleaning.jl"); using .Cleaning

function restore(spw, name)
    path = getdir(spw, name)

    local pixels, peak, major, minor, angle
    jldopen(joinpath(path, "psf-properties.jld2"), "r") do file
        pixels = file["pixels"]
        peak   = file["peak"]
        major  = file["major"]
        minor  = file["minor"]
        angle  = file["angle"]
    end

    local residual_alm, degraded_alm, components
    jldopen(joinpath(path, "clean", "state-01024.jld2"), "r") do file
        residual_alm = file["residual_alm"]
        degraded_alm = file["degraded_alm"]
        components   = file["components"]
    end

    restored_alm = residual_alm + degraded_alm
    restored_map = alm2map(restored_alm, 2048)
    writehealpix(joinpath(path, "clean-map-residuals.fits"), restored_map, replace=true)

    restore!(restored_map, components, pixels, peak, major, minor, angle)
    writehealpix(joinpath(path, "clean-map.fits"), restored_map, replace=true)
    #writehealpix(joinpath(getdir(spw), "$target-$dataset-galactic.fits"),
    #             MModes.rotate_to_galactic(spw, dataset, restored_map), replace=true)
    #writehealpix(joinpath(getdir(spw), "$target-$dataset-j2000.fits"),
    #             MModes.rotate_to_j2000(spw, dataset, restored_map), replace=true)
end

function restore!(restored_map, components, ringstart, peak, major, minor, angle)
    pixels = find(components)
    N = length(pixels)
    prg = Progress(N)
    for pixel in pixels
        ring = searchsortedlast(ringstart, pixel)
        vec  = LibHealpix.pix2vec(restored_map, pixel)
        θ, ϕ = LibHealpix.vec2ang(vec)
        north = SVector(0, 0, 1)
        north -= dot(north, vec)*vec
        north /= norm(north)
        east = cross(north, vec)
        amplitude = components[pixel]*peak[ring]
        disc = query_disc(restored_map, θ, ϕ, deg2rad(1))
        for disc_pixel in disc
            disc_vec = LibHealpix.pix2vec(restored_map, disc_pixel)
            x = asind(dot(disc_vec, east)) * 60
            y = asind(dot(disc_vec, north)) * 60
            value = gaussian(x, y, amplitude, major[ring], minor[ring], deg2rad(angle[ring]))
            restored_map[disc_pixel] += value
        end
        next!(prg)
    end
end

end

