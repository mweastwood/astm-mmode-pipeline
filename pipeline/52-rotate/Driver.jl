module Driver

using CasaCore.Measures
using FileIO, JLD2
using LibHealpix
using ProgressMeter
using TTCal
using Unitful

include("../lib/Common.jl"); using .Common

function rotate(spw, name)
    path = getdir(spw, name)
    map = readhealpix(joinpath(path, "clean-map-kelvin.fits"))

    galactic = rotate_to_galactic(spw, name, map)
    writehealpix(joinpath(path, "clean-map-galactic.fits"), galactic, coordsys="G", replace=true)

    j2000 = rotate_to_j2000(spw, name, map)
    writehealpix(joinpath(path, "clean-map-j2000.fits"), j2000, coordsys="C", replace=true)
end

rotate_to_galactic(spw, name, map) = rotate_to(spw, name, map, dir"GALACTIC")
rotate_to_j2000(spw, name, map) = rotate_to(spw, name, map, dir"J2000")

function rotate_to(spw, name, map, system)
    metadata = load(joinpath(getdir(spw, name), "raw-visibilities.jld2"), "metadata")
    TTCal.slice!(metadata, 1, axis=:time)
    frame = ReferenceFrame(metadata)

    z  = Direction(dir"ITRF", 0u"°", 90u"°")
    z′ = measure(frame, z, system)
    x  = Direction(dir"ITRF", 0u"°",  0u"°")
    x′ = measure(frame, x, system)
    y′ = cross(z′, x′)

    output = RingHealpixMap(Float64, map.nside)
    prg = Progress(length(map))
    for idx = 1:length(map)
        r  = LibHealpix.pix2vec(map, idx)
        r′ = Direction(system, r[1], r[2], r[3])
        θ = acos(dot(r′, z′))
        ϕ = atan2(dot(r′, y′), dot(r′, x′))
        output[idx] = LibHealpix.interpolate(map, θ, ϕ)
        next!(prg)
    end
    output
end

end

