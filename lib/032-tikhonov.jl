module Driver

using BPJSpec
using JLD2
using LibHealpix
using YAML

include("Project.jl")

struct Config
    input :: String
    output_alm :: String
    output_map :: String
    transfermatrix :: String
    regularization :: Float64
    nside :: Int
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["input"], dict["output-alm"], dict["output-map"],
           dict["transfer-matrix"], dict["regularization"], dict["nside"])
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
    alm = BPJSpec.tikhonov(transfermatrix, mmodes, regularization=config.regularization, mfs=true)
    Project.save(project, config.output_alm, "alm", alm)
    #alm = Project.load(project, config.output_alm, "alm")

    # create a Healpix map
    lmax = mmax = alm.mmax
    _alm = Alm(Complex128, lmax, mmax)
    for m = 1:lmax
        block = alm[m]
        for l = m:mmax
            @lm _alm[l, m] = block[l - m + 1]
        end
    end
    map = alm2map(_alm, config.nside)
    writehealpix(joinpath(path, config.output_map*".fits"), map, replace=true)
end

end

