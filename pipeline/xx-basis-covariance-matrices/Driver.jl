module Driver

using BPJSpec
using FileIO, JLD2
using ProgressMeter
using Unitful, UnitfulAstro

include("../lib/Common.jl"); using .Common

function covariance(spw, name)
    path  = getdir(spw, name)
    path′ = joinpath(path, "basis-covariance-matrices")
    isdir(path′) || mkdir(path′)
    model = fiducial()

    transfermatrix = TransferMatrix(joinpath(path, "transfer-matrix-compressed"))
    lmax        = transfermatrix.mmax
    frequencies = transfermatrix.frequencies
    bandwidth   = transfermatrix.bandwidth

    # The high kpara modes are the toughest to compute because of the bandwidth smearing integral,
    # so we will try to do those ones first in order to prevent the progress bar from being
    # misleadingly fast (instead it will be misleadingly slow).
    queue = [(i, j) for i = reverse(1:length(model.kpara)) for j = 1:length(model.kperp)]
    pool  = CachingPool(workers())

    lck = ReentrantLock()
    prg = Progress(length(queue))
    increment() = (lock(lck); next!(prg); unlock(lck))

    @sync for worker in workers()
        @async while length(queue) > 0
            i, j = shift!(queue)
            remotecall_fetch(do_the_thing, pool,
                             path′, lmax, frequencies, bandwidth, model, i, j)
            increment()
        end
    end

    save(joinpath(path′, "FIDUCIAL.jld2"), "model", model)
end

function do_the_thing(path, lmax, frequencies, bandwidth, model, i, j)
    model.power[:]    = 0u"K^2*Mpc^3"
    model.power[i, j] = 1u"K^2*Mpc^3"
    file = joinpath(path, @sprintf("%03d-%03d", i, j))
    AngularCovarianceMatrix(file, lmax, frequencies, bandwidth, model)
    nothing
end

function fiducial()
    kpara = logspace(log10(0.05), log10(1.05), 20).*u"Mpc^-1"
    kperp = linspace(0, 0.02, 10).*u"Mpc^-1"

    power = zeros(length(kpara), length(kperp)) .* u"K^2*Mpc^3"
    BPJSpec.SignalModel((10., 30.), kpara, kperp, power)
end

end

