module Driver

using BPJSpec
using FileIO, JLD2
using Unitful, UnitfulAstro
using ProgressMeter
using YAML

include("Project.jl")

struct Config
    input  :: String
    output :: String
    powerspectrum :: String
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["input"], dict["output"], dict["power-spectrum"])
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    basis_covariance(project, config)
end

function basis_covariance(project, config)
    if config.powerspectrum == "angular"
        model = fiducialangular()
    elseif config.powerspectrum == "spherical"
        model = fiducial1d()
    elseif config.powerspectrum == "cylindrical"
        model = fiducial2d()
    else
        error("unknown power spectrum type $(config.powerspectrum)")
    end

    _basis_covariance(project, config, model)
end

function _basis_covariance(project, config, model)
    path = Project.workspace(project)
    path′ = joinpath(path, config.output)
    isdir(path′) || mkdir(path′)

    mmodes = BPJSpec.load(joinpath(path, config.input))
    lmax        = mmodes.mmax
    frequencies = mmodes.frequencies
    bandwidth   = mmodes.bandwidth

    queue = collect(1:length(model.power))
    lck = ReentrantLock()
    prg = Progress(length(queue))
    increment() = (lock(lck); next!(prg); unlock(lck))

    @sync for worker in workers()
        @async while length(queue) > 0
            idx = shift!(queue)
            remotecall_fetch(generate_covariance_matrix, worker,
                             path′, lmax, frequencies, bandwidth,
                             deepcopy(model), idx)
            increment()
        end
    end

    save(joinpath(path′, "FIDUCIAL.jld2"), "model", model)
end

function generate_covariance_matrix(path, lmax, frequencies, bandwidth, model, idx)
    model.power[:]   = 0 * oneunit(eltype(model.power))
    model.power[idx] = 1 * oneunit(eltype(model.power))
    file = joinpath(path, @sprintf("%03d", idx))
    matrix = BPJSpec.create(AngularCovarianceMatrix, SingleFile(file),
                            model, lmax, frequencies, bandwidth, rm=true)
    nothing
end

function fiducialangular()
    l = [0, 1, 2, 4, 8, 16, 32, 64, 96, 128, 192, 256, 300]
    # we will end up integrating over the channel widths, so we need to make sure we need to cover
    # the full range of frequencies adding a little bit for the channel bandwidth
    ν = linspace(71.856 - 0.024, 74.448 + 0.024, 11) .* u"MHz"
    power = zeros(length(l), length(ν)) .* u"K"
    BPJSpec.GeneralForegroundComponent(l, ν, power)
end

function fiducial1d()
    k     = logspace(log10(0.05), log10(1.05), 10) .* u"Mpc^-1"
    unshift!(k, 0.0u"Mpc^-1")
    power = zeros(length(k)) .* u"K^2*Mpc^3"
    BPJSpec.SphericalPS((10., 30.), k, power)
end

function fiducial2d()
    kpara = logspace(log10(0.05), log10(1.05), 20) .* u"Mpc^-1"
    kperp = linspace(0, 0.03, 10) .* u"Mpc^-1"
    power = zeros(length(kpara), length(kperp)) .* u"K^2*Mpc^3"
    BPJSpec.CylindricalPS((10., 30.), kpara, kperp, power)
end

end

