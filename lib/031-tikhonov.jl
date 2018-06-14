module Driver

using BPJSpec
using CasaCore.Measures
using JLD2
using LibHealpix
using ProgressMeter
using TTCal
using Unitful, UnitfulAstro
using YAML

include("Project.jl")

struct Config
    input :: String
    output_alm :: String
    output_map :: String
    output_directory :: String
    metadata :: String
    transfermatrix :: String
    regularization :: Float64
    nside :: Int
    mfs :: Bool
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["input"],
           dict["output-alm"],
           dict["output-map"],
           get(dict, "output-directory", ""),
           dict["metadata"],
           dict["transfer-matrix"],
           dict["regularization"],
           dict["nside"],
           get(dict, "mfs", true))
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    tikhonov(project, config)
end

function tikhonov(project, config)
    path = Project.workspace(project)
    mmodes = BPJSpec.load(joinpath(path, config.input))
    transfermatrix = BPJSpec.load(joinpath(path, config.transfermatrix))
    metadata = Project.load(project, config.metadata, "metadata")

    if config.mfs
        alm = BPJSpec.tikhonov(transfermatrix, mmodes, mfs=config.mfs,
                               regularization=config.regularization)
        Project.save(project, config.output_alm, "alm", alm)
        #alm = Project.load(project, config.output_alm, "alm")
    else
        alm = BPJSpec.tikhonov(transfermatrix, mmodes, mfs=config.mfs,
                               regularization=config.regularization,
                               storage=MultipleFiles(joinpath(path, config.output_alm)))
    end

    if config.mfs
        map = create_map(alm, metadata, config.nside)
        map = rotate_to_galactic(map, metadata)
        writehealpix(joinpath(path, config.output_map*".fits"), map,
                     coordsys="G", replace=true)
    else
        Nfreq = length(alm.frequencies)
        if !isdir(joinpath(path, config.output_directory))
            mkpath(joinpath(path, config.output_directory))
        end
        prg = Progress(Nfreq)
        for β = 1:Nfreq
            map = create_map(alm, metadata, config.nside, β)
            map = rotate_to_galactic(map, metadata)
            filename = @sprintf("%s-%04d.fits", config.output_map, β)
            writehealpix(joinpath(path, config.output_directory, filename), map,
                         coordsys="G", replace=true)
            next!(prg)
        end
    end
end

function create_map(alm::MBlockVector, metadata, nside)
    lmax = mmax = alm.mmax
    _alm = Alm(Complex128, lmax, mmax)
    for m = 1:lmax
        block = alm[m]
        for l = m:mmax
            @lm _alm[l, m] = block[l - m + 1]
        end
    end
    alm2map(_alm, nside)
end

function create_map(alm::MFBlockVector, metadata, nside, β)
    lmax = mmax = alm.mmax
    _alm = Alm(Complex128, lmax, mmax)
    for m = 1:lmax
        block = alm[m, β]
        for l = m:mmax
            @lm _alm[l, m] = block[l - m + 1]
        end
    end
    alm2map(_alm, nside)
end

function rotate_to_galactic(map, metadata)
    x = Direction(dir"ITRF", 1, 0, 0)
    y = Direction(dir"ITRF", 0, 1, 0)
    z = Direction(dir"ITRF", 0, 0, 1)

    frame = ReferenceFrame(metadata)
    ξ = measure(frame, x, dir"GALACTIC")
    η = measure(frame, y, dir"GALACTIC")
    ζ = measure(frame, z, dir"GALACTIC")

    output = RingHealpixMap(eltype(map), map.nside)
    for idx = 1:length(map)
        vec = LibHealpix.pix2vec(map, idx)
        dir = Direction(dir"GALACTIC", vec.x, vec.y, vec.z)
        θ =  acos(dot(dir, ζ))
        ϕ = atan2(dot(dir, η), dot(dir, ξ))
        output[idx] = LibHealpix.interpolate(map, θ, ϕ)
    end
    output
end

end

