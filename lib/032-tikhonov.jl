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
    mmodes = MModes(joinpath(path, config.input))
    transfermatrix = HierarchicalTransferMatrix(joinpath(path, config.transfermatrix))
    alm = BPJSpec.tikhonov(transfermatrix, mmodes, config.regularization)
    jldopen(joinpath(path, config.output_alm*".jld2"), "w") do file
        file["alm"] = alm
    end
    # create a Healpix map
    _alm = Alm(Complex128, alm.lmax, alm.mmax)
    for m = 1:alm.lmax, l = m:alm.mmax
        @lm _alm[l, m] = alm[l, m]
    end
    map = alm2map(_alm, config.nside)
    writehealpix(joinpath(path, config.output_map*".fits"), map, replace=true)
end

end

