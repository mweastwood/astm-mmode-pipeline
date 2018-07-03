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

struct AngularConfig
    l :: Vector{Int}
    ν :: Vector{typeof(1.0u"MHz")}
end

struct SphericalConfig
    k :: Vector{typeof(1.0u"Mpc^-1")}
end

struct CylindricalConfig
    kpara :: Vector{typeof(1.0u"Mpc^-1")}
    kperp :: Vector{typeof(1.0u"Mpc^-1")}
end

function load(file)
    dict = YAML.load(open(file))
    config = Config(dict["input"], dict["output"], dict["power-spectrum"])
    if config.powerspectrum == "angular"
        psconfig = AngularConfig(dict["l"], dict["frequencies"] .* u"MHz")
    elseif config.powerspectrum == "spherical"
        psconfig = SphericalConfig(dict["k"] .* u"Mpc^-1")
    elseif config.powerspectrum == "cylindrical"
        psconfig = CylindricalConfig(dict["kpara"] .* u"Mpc^-1", dict["kpara"] .* u"Mpc^-1")
    else
        error("unknown power spectrum type $(config.powerspectrum)")
    end
    config, psconfig
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config, psconfig = load(config_file)
    basis_covariance(project, config, psconfig)
end

function basis_covariance(project, config, psconfig)
    model = getmodel(psconfig)
    _basis_covariance(project, config, model)
end

function _basis_covariance(project, config, model)
    path = Project.workspace(project)

    mmodes = BPJSpec.load(joinpath(path, config.input))
    lmax        = mmodes.mmax
    frequencies = mmodes.frequencies
    bandwidth   = mmodes.bandwidth

    queue = collect(1:length(model.power))
    lck = ReentrantLock()
    prg = Progress(length(queue))
    increment() = (lock(lck); next!(prg); unlock(lck))

    output = Array{BPJSpec.LBlockMatrix}(length(queue))

    @sync for worker in workers()
        @async while length(queue) > 0
            idx = shift!(queue)
            output[idx] = remotecall_fetch(generate_covariance_matrix, worker,
                                           lmax, frequencies, bandwidth,
                                           deepcopy(model), idx)
            increment()
        end
    end

    save(joinpath(path, config.output*".jld2"), "model", model,
         "covariance-matrices", output)
end

function generate_covariance_matrix(lmax, frequencies, bandwidth, model, idx)
    model.power[:]   = 0 * oneunit(eltype(model.power))
    model.power[idx] = 1 * oneunit(eltype(model.power))
    BPJSpec.create(AngularCovarianceMatrix, NoFile(),
                   model, lmax, frequencies, bandwidth)
end

function getmodel(psconfig::AngularConfig)
    power = zeros(length(psconfig.l), length(psconfig.ν)) .* u"K"
    BPJSpec.GeneralForegroundComponent(psconfig.l, psconfig.ν, power)
end

function getmodel(psconfig::SphericalConfig)
    power = zeros(length(psconfig.k)) .* u"K^2*Mpc^3"
    BPJSpec.SphericalPS((10., 30.), psconfig.k, power)
end

function getmodel(psconfig::CylindricalConfig)
    power = zeros(length(psconfig.kpara), length(psconfig.kperp)) .* u"K^2*Mpc^3"
    BPJSpec.CylindricalPS((10., 30.), psconfig.kpara, psconfig.kperp, power)
end

end

