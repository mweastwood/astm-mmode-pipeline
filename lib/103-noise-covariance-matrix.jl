module Driver

using BPJSpec
using Unitful
using YAML

include("Project.jl")

struct Config
    input  :: String
    output :: String
    Tsys :: Float64
    integration_time :: Float64
    number_of_integrations :: Int
    beam_solid_angle :: Float64
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["input"], dict["output"], dict["Tsys"], dict["integration-time"],
           dict["number-of-integrations"], dict["beam-solid-angle"])
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    noise_covariance(project, config)
    Project.touch(project, config.output)
end

function noise_covariance(project, config)
    path = Project.workspace(project)

    mmodes = BPJSpec.load(joinpath(path, config.input))
    matrix = BPJSpec.create(NoiseCovarianceMatrix, mmodes.mmax,
                            mmodes.frequencies, mmodes.bandwidth)

    noisemodel = BPJSpec.NoiseModel(config.Tsys*u"K", config.integration_time*u"s",
                                    config.number_of_integrations, config.beam_solid_angle*u"sr")
    compute!(matrix, noisemodel, mmodes, progress=true)
end

end

