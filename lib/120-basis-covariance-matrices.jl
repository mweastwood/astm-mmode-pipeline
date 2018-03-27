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
    Project.touch(project, config.output)
end

function basis_covariance(project, config)
    path = Project.workspace(project)
    path′ = joinpath(path, config.output)
    isdir(path′) || mkdir(path′)

    if config.powerspectrum == "spherical"
        model = fiducial1d()
    elseif config.powerspectrum == "cylindrical"
        model = fiducial2d()
    else
        error("unknown power spectrum type $(config.powerspectrum)")
    end

    mmodes = BPJSpec.load(joinpath(path, config.input))
    lmax        = mmodes.mmax
    frequencies = mmodes.frequencies
    bandwidth   = mmodes.bandwidth

    queue = collect(1:length(model.power))
    pool  = CachingPool(workers())
    lck = ReentrantLock()
    prg = Progress(length(queue))
    increment() = (lock(lck); next!(prg); unlock(lck))

    @sync for worker in workers()
        @async while length(queue) > 0
            idx = shift!(queue)
            remotecall_fetch(do_the_thing, pool,
                             path′, lmax, frequencies, bandwidth,
                             deepcopy(model), idx)
            increment()
        end
    end

    save(joinpath(path′, "FIDUCIAL.jld2"), "model", model)
end

function do_the_thing(path, lmax, frequencies, bandwidth, model, idx)
    model.power[:]   = 0u"K^2*Mpc^3"
    model.power[idx] = 1u"K^2*Mpc^3"
    file = joinpath(path, @sprintf("%03d", idx))
    matrix = BPJSpec.create(AngularCovarianceMatrix, SingleFile(file),
                            model, lmax, frequencies, bandwidth)
    nothing
end

function fiducial1d()
    k     = logspace(log10(0.05), log10(1.05), 10) .* u"Mpc^-1"
    unshift!(k, 0.0u"Mpc^-1")
    power = zeros(length(k)) .* u"K^2*Mpc^3"
    BPJSpec.SphericalPS((10., 30.), k, power)
end

function fiducial2d()
    kpara = logspace(log10(0.05), log10(1.05), 20) .* u"Mpc^-1"
    kperp = linspace(0, 0.02, 10) .* u"Mpc^-1"
    power = zeros(length(kpara), length(kperp)) .* u"K^2*Mpc^3"
    BPJSpec.CylindricalPS((10., 30.), kpara, kperp, power)
end

end

