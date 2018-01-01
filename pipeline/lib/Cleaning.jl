module Cleaning

export Worker, distribute_responsibilities, load_observation_matrix
export pointsource_alm, gaussian_alm, convolve, observe!
export unit_vectors, postage_stamp, local_workers

using GSL
using LibHealpix
using StaticArrays

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

"Get a list of the local workers."
function local_workers()
    hostname() = readstring(`hostname`)
    futures = [remotecall(hostname, worker) for worker in workers()]
    hosts   = [fetch(future) for future in futures]
    workers()[hosts .== hostname()]
end

"Distribute the blocks amongst all available workers."
function distribute_responsibilities(mmax)
    # Note that we are choosing to discard m=0 here by not assigning it to any worker.
    Dict(worker => idx:nworkers():mmax for (idx, worker) in enumerate(workers()))
end

"Corrupt the alm as if it was observed by the interferometer."
function observe!(alm, responsibilities)
    @sync for worker in keys(responsibilities)
        @async for m in responsibilities[worker]
            a = @lm alm[:, m]
            b = remotecall_fetch(Worker.observe, worker, a, m)
            @lm alm[:, m] = b
        end
    end
    alm
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

"Load the observation matrix on each worker."
function load_observation_matrix(path, responsibilities)
    @sync for worker in keys(responsibilities)
        @async remotecall_wait(Worker.load, worker, path, responsibilities[worker])
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

function gaussian_alm(fwhm, lmax, mmax)
    # note: fwhm in degrees
    σ = fwhm/(2sqrt(2log(2)))
    kernel = RingHealpixMap(Float64, 512)
    for pix = 1:length(kernel)
        θ, ϕ = LibHealpix.pix2ang(kernel, pix)
        θ = rad2deg(θ)
        kernel[pix] = exp(-θ^2/(2σ^2))
    end
    dΩ = 4π/length(kernel)
    kernel /= sum(kernel)*dΩ
    kernel_alm = map2alm(kernel, 1000, 1000, iterations=10)
    output = Alm(Complex128, lmax, mmax)
    for (l, m) in lm(kernel_alm)
        @lm output[l, m] = @lm kernel_alm[l, m]
    end
    output
end

function convolve(alm1, alm2)
    output_alm = Alm(Complex128, alm1.lmax, alm1.mmax)
    for m = 0:alm1.mmax, l = m:alm1.lmax
        a1 = @lm alm1[l, m]
        a2 = @lm alm2[l, 0]
        @lm output_alm[l, m] = sqrt((4π)/(2l+1))*a1*a2
    end
    output_alm
end

function unit_vectors(nside)
    npix = nside2npix(nside)
    x = RingHealpixMap(Float64, nside)
    y = RingHealpixMap(Float64, nside)
    z = RingHealpixMap(Float64, nside)
    for pix = 1:npix
        vec = pix2vec(x, pix)
        x[pix] = vec[1]
        y[pix] = vec[2]
        z[pix] = vec[3]
    end
    x, y, z
end

end

