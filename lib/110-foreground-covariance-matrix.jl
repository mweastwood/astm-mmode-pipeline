module Driver

using BPJSpec
using YAML
using Unitful

include("Project.jl")

struct Config
    input  :: String
    output :: String
    ν0 :: Float64
    A  :: Float64
    α  :: Float64
    β  :: Float64
    ζ  :: Float64
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["input"],
           dict["output"],
           get(dict, "nu", 0.0),
           get(dict, "A",  0.0),
           get(dict, "alpha", 0.0),
           get(dict, "beta",  0.0),
           get(dict, "zeta",  0.0))
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    foreground_covariance(project, config)
end

function foreground_covariance(project, config)
    path = Project.workspace(project)

    mmodes = BPJSpec.load(joinpath(path, config.input))
    lmax = mmodes.mmax

    if config.ν0 == 0
        points   = create(AngularCovarianceMatrix, NoFile(), BPJSpec.extragalactic_point_sources(),
                          lmax, mmodes.frequencies, mmodes.bandwidth, progress=true)
        galactic = create(AngularCovarianceMatrix, NoFile(), BPJSpec.galactic_synchrotron(),
                          lmax, mmodes.frequencies, mmodes.bandwidth, progress=true)
        foregrounds = create(LBlockMatrix, SingleFile(joinpath(path, config.output)),
                             lmax, mmodes.frequencies, mmodes.bandwidth, rm=true) |> ProgressBar
        @. foregrounds = points + galactic
    else
        foreground = BPJSpec.ForegroundComponent(config.ν0 * u"MHz",
                                                 config.A  * u"mK^2",
                                                 config.α, config.β, config.ζ)
        foregrounds = create(AngularCovarianceMatrix, SingleFile(joinpath(path, config.output)),
                             foreground, lmax, mmodes.frequencies, mmodes.bandwidth,
                             rm=true, progress=true)
    end
end

end

