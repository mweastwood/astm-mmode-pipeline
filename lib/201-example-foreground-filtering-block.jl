module Driver

using BPJSpec
using FileIO, JLD2
using YAML

include("Project.jl")

struct Config
    transfermatrix    :: String
    noisematrix       :: String
    signalmatrix      :: String
    foregroundmatrix  :: String
    foreground_filter :: String
    noise_whitener    :: String
    output            :: String
    m :: Int
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["transfer-matrix"],
           dict["noise-matrix"],
           dict["signal-matrix"],
           dict["foreground-matrix"],
           dict["foreground-filter"],
           dict["noise-whitener"],
           dict["output"],
           dict["m"])
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    extract_a_block(project, config)
end

function foreground_filter(project, config)
    path = Project.workspace(project)

    transfermatrix    = BPJSpec.load(joinpath(path, config.transfermatrix))
    noisematrix       = BPJSpec.load(joinpath(path, config.noisematrix))
    signalmatrix      = BPJSpec.load(joinpath(path, config.signalmatrix))
    foregroundmatrix  = BPJSpec.load(joinpath(path, config.foregroundmatrix))
    foreground_filter = BPJSpec.load(joinpath(path, config.foreground_filter))
    noise_whitener    = BPJSpec.load(joinpath(path, config.noise_whitener))

    m = config.m
    B = transfermatrix[m]
    N = noisematrix[m]
    S = signalmatrix[m]
    F = foregroundmatrix[m]
    L = foreground_filter[m]
    W = noise_whitener[m]

    FileIO.save(joinpath(path, config.output*".jld2"),
                "m", m, "B", B, "N", N, "S", S, "F", F, "L", L, "W", W)
end

end

