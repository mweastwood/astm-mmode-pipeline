module Driver

using GSL
using JLD2
using LibHealpix
using ProgressMeter
using StaticArrays

include("../lib/Common.jl"); using .Common

module Worker
    using JLD2
    using LibHealpix

    const observation_matrix_blocks     = Dict{Int, Matrix{Complex128}}()
    const cholesky_decomposition_blocks = Dict{Int, Matrix{Complex128}}()

    function load(path, list_of_m)
        jldopen(path, "r") do file
            for m in list_of_m
                if !haskey(observation_matrix_blocks, m)
                    observation_matrix_blocks[m]     = file[@sprintf("%06d-block",    m)]
                    cholesky_decomposition_blocks[m] = file[@sprintf("%06d-cholesky", m)]
                end
            end
        end
    end

    function observe(a, m)
        BLAS.set_num_threads(1)
        BB = observation_matrix_blocks[m]
        U  = cholesky_decomposition_blocks[m]
        f(BB, U, a)
    end

    f(BB, U, a) = U\(U'\(BB*a))
end

function psf(spw, name)
    path = joinpath(getdir(spw, name), "observation-matrix.jld2")
    local lmax, mmax
    jldopen(path, "r") do file
        lmax = file["lmax"]
        mmax = file["mmax"]
    end
    nside = 2048
    pixels, peak, major, minor, angle = compute(path, lmax, mmax, nside)
    jldopen(joinpath(getdir(spw, name), "psf-properties.jld2"), "w") do file
        file["lmax"]   = lmax
        file["mmax"]   = mmax
        file["nside"]  = nside
        file["pixels"] = pixels
        file["peak"]   = peak
        file["major"]  = major
        file["minor"]  = minor
        file["angle"]  = angle
    end
end

function compute(path, lmax, mmax, nside)
    pixels = find_healpix_rings(nside)
    responsibilities = distribute_responsibilities(mmax)
    @time load_observation_matrix(path, responsibilities)

    N = length(pixels)
    peak  = zeros(N)
    major = zeros(N)
    minor = zeros(N)
    angle = zeros(N)

    prg = Progress(N)
    for idx = 1:N
        pixel = pixels[idx]
        θ, ϕ = LibHealpix.pix2ang_ring(nside, pixel)
        alm = psf_alm(θ, ϕ, lmax, mmax, responsibilities)
        map = alm2map(alm, nside)
        peak[idx], major[idx], minor[idx], angle[idx] = psf_properties(map, pixel)
        next!(prg)
    end

    pixels, peak, major, minor, angle
end

function psf_alm(θ, ϕ, lmax, mmax, responsibilities)
    alm = pointsource_alm(θ, ϕ, lmax, mmax)
    observe!(alm, responsibilities)
    alm
end

function observe!(alm, responsibilities)
    @sync for worker in keys(responsibilities)
        @async for m in responsibilities[worker]
            a = @lm alm[:, m]
            b = remotecall_fetch(Worker.observe, worker, a, m)
            @lm alm[:, m] = b
        end
    end
end

function psf_properties(map, pixel; extent=1)
    vec = LibHealpix.pix2vec_ring(map.nside, pixel)
    img = postage_stamp(map, pixel; extent=extent)

    # Compute the peak value of the PSF
    peak = map[pixel]
    img ./= peak

    # Compute the major and minor axes
    xgrid = linspace(-deg2rad(extent), +deg2rad(extent), 1001)
    ygrid = linspace(-deg2rad(extent), +deg2rad(extent), 1001)
    keep_y, keep_x = findn(img .> 0.5)
    count = length(keep_x)
    x = xgrid[keep_x]
    y = ygrid[keep_y]
    A = [x y]
    U, S, V = svd(A)
    major_axis = V[:, 1]
    minor_axis = V[:, 2]
    major_scale = S[1]
    minor_scale = S[2]

    # Compute the FWHM by assuming all pixels > 0.5 fill an elliptical aperture
    dΩ = ((2extent)^2 / (180/π)^2) / (length(xgrid)*length(ygrid))
    Ω = count * dΩ

    C = sqrt(Ω/(π*major_scale*minor_scale))
    major_hwhm = C*major_scale
    minor_hwhm = C*minor_scale
    major_fwhm = 2major_hwhm
    minor_fwhm = 2minor_hwhm
    major_σ = major_fwhm/(2sqrt(2log(2)))
    minor_σ = minor_fwhm/(2sqrt(2log(2)))
    angle = atan2(major_axis[1], major_axis[2])

    major_σ = 60rad2deg(major_σ)
    minor_σ = 60rad2deg(minor_σ)
    angle = rad2deg(angle)

    peak, major_σ, minor_σ, angle
end

"Compute the spherical harmonic coefficients for a point source at the given coordinates."
function pointsource_alm(θ, ϕ, lmax, mmax)
    cosθ = cos(θ)
    alm = Alm(Complex128, lmax, mmax)
    for m = 0:mmax
        coeff = GSL.sf_legendre_sphPlm_array(lmax, m, cosθ)
        cismϕ = cis(-m*ϕ)
        for l = m:lmax
            @lm alm[l, m] = coeff[l-m+1]*cismϕ
        end
    end
    alm
end

"Distribute the blocks amongst all available workers."
function distribute_responsibilities(mmax)
    # Note that we are choosing to discard m=0 here by not assigning it to any worker.
    Dict(worker => idx:nworkers():mmax for (idx, worker) in enumerate(workers()))
end

"Load the observation matrix on each worker."
function load_observation_matrix(path, responsibilities)
    @sync for worker in keys(responsibilities)
        @async remotecall_wait(Worker.load, worker, path, responsibilities[worker])
    end
end

"Starting pixel of each Healpix ring."
function find_healpix_rings(nside)
    nring  = nside2nring(nside)
    pixels = [LibHealpix.ring_info2(nside, ring)[1] for ring = 1:nring]
    # discard pixels below -30 dec
    filter!(pixels) do pixel
        θ, ϕ = LibHealpix.pix2ang_ring(nside, pixel)
        θ < deg2rad(120)
    end
end

"Cutout a 1° by 1° image of the pixel."
function postage_stamp(map, pixel; extent=1)
    z  = LibHealpix.pix2vec_ring(map.nside, pixel)
    y  = SVector(0, 0, 1)
    y -= dot(y, z)*z
    y /= norm(y)
    x  = cross(y, z)
    xgrid = linspace(-deg2rad(extent), +deg2rad(extent), 1001)
    ygrid = linspace(-deg2rad(extent), +deg2rad(extent), 1001)
    image = zeros(length(ygrid), length(xgrid))
    for idx = 1:length(xgrid), jdx = 1:length(ygrid)
        vector = xgrid[idx]*x + ygrid[jdx]*y + z
        vector /= norm(vector)
        θ = acos(vector[3])
        ϕ = mod2pi(atan2(vector[2], vector[1]))
        image[jdx, idx] = LibHealpix.interpolate(map, θ, ϕ)
    end
    image
end

end

