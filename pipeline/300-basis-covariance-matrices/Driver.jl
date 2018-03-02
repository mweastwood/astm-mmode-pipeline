module Driver

using BPJSpec
using FileIO, JLD2
using ProgressMeter
using Unitful, UnitfulAstro

include("../lib/Common.jl"); using .Common

function covariance(spw, name; ps=:spherical)
    path  = getdir(spw, name)
    path′ = joinpath(path, "basis-covariance-matrices")
    isdir(path′) || mkdir(path′)

    if ps == :spherical
        model = fiducial1d()
    elseif ps == :cylindrical
        model = fiducial2d()
    else
        error("unknown power spectrum type $ps")
    end

    transfermatrix = TransferMatrix(joinpath(path, "transfer-matrix-averaged"))
    lmax        = transfermatrix.mmax
    frequencies = transfermatrix.frequencies
    bandwidth   = transfermatrix.bandwidth

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
    AngularCovarianceMatrix(file, lmax, frequencies, bandwidth, model)
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

