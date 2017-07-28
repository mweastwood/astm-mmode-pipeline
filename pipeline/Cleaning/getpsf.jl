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
    N = 360
    θ = linspace(0, π, N)
    peaks = zeros(N)
    prg = Progress(N)
    for idx = 1:N
        peaks[idx] = getpsf_peak(observation_matrix, θ[idx], 0, nside, lmax, mmax)
        next!(prg)
    end
    save(joinpath(dir, "psf-peak-value-$dataset.jld"), "theta", θ, "peaks", peaks)
end

function getpsf_peak(observation_matrix, θ, ϕ, nside, lmax, mmax)
    map = getpsf(observation_matrix, θ, ϕ, nside, lmax, mmax)
    # TODO interpolate to the center of the PSF instead of just blindly taking the maximum
    maximum(map.pixels)
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

