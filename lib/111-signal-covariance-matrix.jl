module Driver

using BPJSpec
using Unitful, UnitfulAstro
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
    signal_covariance(project, config)
    Project.touch(project, config.output)
end

function signal_covariance(project, config)
    path = Project.workspace(project)

    mmodes = BPJSpec.load(joinpath(path, config.input))
    lmax = mmodes.mmax

    signal = BPJSpec.create(AngularCovarianceMatrix, SingleFile(joinpath(path, config.output)),
                            fiducial_signal_model(),
                            lmax, mmodes.frequencies, mmodes.bandwidth,
                            rm=true, progress=true)
end

function fiducial_signal_model()
    kpara = logspace(log10(0.01), log10(1.0), 200) .* u"Mpc^-1"
    kperp = logspace(log10(0.01), log10(1.0), 200) .* u"Mpc^-1"
    unshift!(kpara, 0u"Mpc^-1")
    unshift!(kperp, 0u"Mpc^-1")
    k = sqrt.(kpara.^2 .+ kperp.'.^2)
    Δ21 = min.(40 .* (k./(0.03u"Mpc^-1")).^2, 400) .* u"mK^2"
    P21 = Δ21 .* 2π^2 ./ (k+0.05u"Mpc^-1").^3
    BPJSpec.CylindricalPS((10., 30.), kpara, kperp, P21)
end

end

