module Driver

using BPJSpec
using YAML

include("Project.jl")

struct Config
    input  :: String
    output :: String
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["input"], dict["output"])
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    foreground_covariance(project, config)
    Project.touch(project, config.output)
end

function foreground_covariance(project, config)
    path = Project.workspace(project)

    mmodes = BPJSpec.load(joinpath(path, config.input))
    lmax = mmodes.mmax

    points   = create(AngularCovarianceMatrix, NoFile(), BPJSpec.extragalactic_point_sources(),
                      lmax, mmodes.frequencies, mmodes.bandwidth, progress=true)
    galactic = create(AngularCovarianceMatrix, NoFile(), BPJSpec.galactic_synchrotron(),
                      lmax, mmodes.frequencies, mmodes.bandwidth, progress=true)

    foregrounds = create(LBlockMatrix, SingleFile(joinpath(path, config.output)),
                         lmax, mmodes.frequencies, mmodes.bandwidth, rm=true) |> ProgressBar
    @. foregrounds = points + galactic
end

end

