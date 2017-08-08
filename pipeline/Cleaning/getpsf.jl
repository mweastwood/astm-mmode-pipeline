# Get the psf for the given spherical coordinates (θ, ϕ)

function getpsf(spw, dataset, θ, ϕ, nside)
    dir = getdir(spw)
    observation_matrix, lmax, mmax = load(joinpath(dir, "observation-matrix-$dataset.jld"),
                                          "blocks", "lmax", "mmax")
    psf = getpsf(observation_matrix, θ, ϕ, 2048, lmax, mmax)
    writehealpix(joinpath(dir, "psf.fits"), psf, replace=true)
end

function getpsf(observation_matrix, θ, ϕ, nside, lmax, mmax)
    alm = getpsf_alm(observation_matrix, θ, ϕ, lmax, mmax)
    alm2map(alm, nside)
end

function getpsf_alm(observation_matrix, θ, ϕ, lmax, mmax)
    input_alm = pointsource_alm(θ, ϕ, lmax, mmax)
    output_alm = Alm(Complex128, lmax, mmax)
    for m = 0:mmax
        A = observation_matrix[m+1]
        x = [input_alm[l, m] for l = m:lmax]
        y = A*x
        for l = m:lmax
            output_alm[l, m] = y[l-m+1]
        end
    end
    output_alm
end

import GSL
function pointsource_alm(θ, ϕ, lmax, mmax)
    cosθ = cos(θ)
    alm = Alm(Complex128, lmax, mmax)
    for m = 0:mmax
        coeff = GSL.sf_legendre_sphPlm_array(lmax, m, cosθ)
        cismϕ = cis(-m*ϕ)
        for l = m:lmax
            alm[l, m] = coeff[l-m+1]*cismϕ
        end
    end
    alm
end

# We want to be able to translate pixel values in the map to flux units. So we will compute the PSF
# at a range of declinations and read off the peak pixel value. We will then interpolate this
# function while cleaning.

function getpsf_peak(spw, dataset, nside=2048)
    dir = getdir(spw)
    observation_matrix, lmax, mmax = load(joinpath(dir, "observation-matrix-$dataset.jld"),
                                          "blocks", "lmax", "mmax")
    θ = Float64[]
    pixels = Int[]
    prg = Progress(nside2npix(nside)÷4)
    for pixel = 1:4:nside2npix(nside)
        myθ, myϕ = LibHealpix.pix2ang_ring(nside, pixel)
        if !(myθ in θ)
            push!(θ, myθ)
            push!(pixels, pixel)
        end
        next!(prg)
    end

    N = length(pixels)
    peaks = zeros(N)
    lck = ReentrantLock()
    prg = Progress(N)

    idx = 1
    nextidx() = (myidx = idx; idx += 1; myidx)
    output(peak, idx) = peaks[idx] = peak
    increment() = (lock(lck); next!(prg); unlock(lck))
    @sync for worker in workers()
        @async begin
            input_channel  = RemoteChannel()
            output_channel = RemoteChannel()
            try
                remotecall(getpsf_worker_loop, worker, input_channel, output_channel,
                           observation_matrix, nside, lmax, mmax)
                while true
                    myidx = nextidx()
                    myidx ≤ N || break
                    put!(input_channel, pixels[myidx])
                    output(take!(output_channel), myidx)
                    increment()
                end
            finally
                close(input_channel)
                close(output_channel)
            end
        end
    end
    save(joinpath(dir, "psf-peak-value-$dataset.jld"), "theta", θ, "peaks", peaks)
end

function getpsf_worker_loop(input, output, observation_matrix, nside, lmax, mmax)
    while true
        try
            pixel = take!(input)
            put!(output, getpsf_peak(observation_matrix, pixel, nside, lmax, mmax))
        catch exception
            if isa(exception, RemoteException) || isa(exception, InvalidStateException)
                break
            else
                @show m
                run(`hostname`)
                println(exception)
                rethrow(exception)
            end
        end
    end
end

function getpsf_peak(observation_matrix, pixel, nside, lmax, mmax)
    θ, ϕ = LibHealpix.pix2ang_ring(nside, pixel)
    map = getpsf(observation_matrix, θ, ϕ, nside, lmax, mmax)
    map[pixel]
end

immutable PSFPeakValues
    θ :: Vector{Float64} # angle from north in radians
    values :: Vector{Float64}
end

function loadpsf_peak(spw::Integer, dataset)
    dir = getdir(spw)
    θ, values = load(joinpath(dir, "psf-peak-value-$dataset.jld"), "theta", "peaks")
    PSFPeakValues(θ, values)
end

function loadpsf_peak(spws::AbstractVector, dataset)
    PSFPeakValues[loadpsf_peak(spw, dataset) for spw in spws]
end

function getpeak(psfpeaks::PSFPeakValues, θ)
    idx = searchsortedlast(psfpeaks.θ, θ)
    psfpeaks.values[idx]
end

