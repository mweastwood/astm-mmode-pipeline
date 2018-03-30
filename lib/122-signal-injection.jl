module Driver

using BPJSpec
using Unitful
using FileIO, JLD2
using YAML

include("Project.jl")

struct Config
    output                :: String
    transfermatrix        :: String
    foreground_filter     :: String
    noise_whitener        :: String
    injection_temperature :: Float64
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["output"],
           dict["transfer-matrix"],
           dict["foreground-filter"],
           dict["noise-whitener"],
           dict["injection-temperature"])
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    inject(project, config)
end

function inject(project, config)
    path = Project.workspace(project)

    transfermatrix    = BPJSpec.load(joinpath(path, config.transfermatrix))
    foreground_filter = BPJSpec.load(joinpath(path, config.foreground_filter))
    noise_whitener    = BPJSpec.load(joinpath(path, config.noise_whitener))

    lmax = mmax = transfermatrix.mmax
    frequencies = transfermatrix.frequencies
    bandwidth   = transfermatrix.bandwidth
    temp = config.injection_temperature * u"mK"

    angularcovariance = create(AngularCovarianceMatrix, NoFile(), signal_model(temp),
                               lmax, frequencies, bandwidth, progress=true)
    random = RandomBlockVector(angularcovariance)
    signal = create(LMBlockVector, lmax, mmax, frequencies, bandwidth)
    @. signal = random
    signal′ = create(MFBlockVector, signal)

    intermediate  = create(MFBlockVector, NoFile(), mmax, frequencies, bandwidth)
    intermediate′ = ProgressBar(intermediate)
    @. intermediate′ = transfermatrix * signal′

    output  = create(MBlockVector, SingleFile(joinpath(path, config.output)), mmax, rm=true)
    output′ = ProgressBar(output)
    @. output′ = T(noise_whitener) * (T(foreground_filter) * intermediate)
end

function signal_model(temp)
    kpara = logspace(log10(0.01), log10(1.0), 200) .* u"Mpc^-1"
    kperp = logspace(log10(0.01), log10(1.0), 200) .* u"Mpc^-1"
    unshift!(kpara, 0u"Mpc^-1")
    unshift!(kperp, 0u"Mpc^-1")

    k = sqrt.(kpara.^2 .+ kperp.'.^2)
    Δ21 = fill(temp^2, size(k))
    P21 = Δ21 .* 2π^2 ./ (k+0.01u"Mpc^-1").^3
    BPJSpec.CylindricalPS((10., 30.), kpara, kperp, P21)
end

end

