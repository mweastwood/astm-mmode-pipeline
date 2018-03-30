module Driver

using BPJSpec
using JLD2
using LibHealpix
using ProgressMeter
using YAML

include("Project.jl")

struct Config
    input :: String
    output_alm :: String
    output_map :: String
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
           dict["transfer-matrix"],
           dict["regularization"],
           dict["nside"],
           get(dict, "mfs", true))
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    tikhonov(project, config)
    Project.touch(project, config.output_map)
end

function tikhonov(project, config)
    path = Project.workspace(project)
    mmodes = BPJSpec.load(joinpath(path, config.input))
    transfermatrix = BPJSpec.load(joinpath(path, config.transfermatrix))
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
        map = create_map(alm, config.nside)
        writehealpix(joinpath(path, config.output_map*".fits"), map, replace=true)
    else
        Nfreq = length(alm.frequencies)
        prg = Progress(Nfreq)
        for β = 1:Nfreq
            map = create_map(alm, config.nside, β)
            filename = @sprintf("%s-%04d.fits", config.output_map, β)
            writehealpix(joinpath(path, filename), map, replace=true)
            next!(prg)
        end
    end
end

function create_map(alm::MBlockVector, nside)
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

function create_map(alm::MFBlockVector, nside, β)
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

end

