module Driver

using TTCal
using BPJSpec
using Unitful
using YAML

include("Project.jl")

struct Config
    metadata :: String
    hierarchy :: String
    input  :: String
    output :: String
    Tsys :: Float64
    beam_solid_angle :: Float64
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["metadata"], dict["hierarchy"], dict["input"], dict["output"],
           dict["Tsys"], dict["beam-solid-angle"])
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    noise_covariance(project, config)
    Project.touch(project, config.output)
end

function noise_covariance(project, config)
    path = Project.workspace(project)


    ttcal_metadata   = Project.load(project, config.metadata, "metadata")
    bpjspec_metadata = BPJSpec.from_ttcal(ttcal_metadata)
    hierarchy        = Project.load(project, config.hierarchy, "hierarchy")

    # We'd like to use the frequency and bandwidth values post-averaging, so we'll read this out
    # from the averaged transfer matrix and update the metadata accordingly.
    transfermatrix = BPJSpec.load(joinpath(path, config.input))
    metadata = BPJSpec.Metadata(transfermatrix.frequencies, transfermatrix.bandwidth,
                                bpjspec_metadata.position, bpjspec_metadata.baselines,
                                bpjspec_metadata.phase_center)

    T = config.Tsys*u"K"
    τ = (ttcal_metadata.times[2].time - ttcal_metadata.times[1].time)*u"s"
    N = Ntime(ttcal_metadata)
    Ω = config.beam_solid_angle*u"sr"
    model = BPJSpec.NoiseModel(T, τ, N, Ω)

    matrix = BPJSpec.create(NoiseCovarianceMatrix, joinpath(path, config.output),
                            model, metadata, hierarchy, rm=true, progress=true)
end

end

