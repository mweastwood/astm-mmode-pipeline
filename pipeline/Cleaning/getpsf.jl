immutable PSF
    pixels :: Vector{Int}
    amplitudes :: Vector{Float64}
    nside :: Int
    lmax :: Int
    mmax :: Int
end

function getpsf(spw, dataset, nside=2048)
    output_directory = joinpath(getdir(spw), "psf")
    isdir(output_directory) || mkdir(output_directory)

    path = joinpath(getdir(spw), "observation-matrix-$dataset.jld")
    lmax, mmax, mrange = load(path, "lmax", "mmax", "mrange")
    observation_matrix, cholesky_decomposition = load(path, "blocks", "cholesky")

    pixels, amplitudes = _getpsf(observation_matrix, cholesky_decomposition,
                                 nside, lmax, mmax, mrange, output_directory)

    psf = PSF(pixels, amplitudes, nside, lmax, mmax)
    save(joinpath(output_directory, "psf.jld"), "psf", psf)
    psf
end

function _getpsf(observation_matrix, cholesky_decomposition,
                 nside, lmax, mmax, mrange, output_directory)
    pixels = find_healpix_rings(nside)

    N = length(pixels)
    amplitudes = zeros(N)
    lck = ReentrantLock()
    prg = Progress(N)

    idx = 1
    nextidx() = (myidx = idx; idx += 1; myidx)
    output(amplitude, idx) = amplitudes[idx] = amplitude
    increment() = (lock(lck); next!(prg); unlock(lck))
    @sync for worker in workers()
        @async begin
            input_channel  = RemoteChannel()
            output_channel = RemoteChannel()
            try
                remotecall(getpsf_worker_loop, worker, input_channel, output_channel,
                           observation_matrix, cholesky_decomposition,
                           nside, lmax, mmax, mrange, output_directory)
                while true
                    myidx = nextidx()
                    myidx ≤ N || break
                    put!(input_channel, pixels[myidx])
                    amplitude = take!(output_channel)
                    output(amplitude, myidx)
                    increment()
                end
            finally
                close(input_channel)
                close(output_channel)
            end
        end
    end

    pixels, amplitudes
end

function getpsf_worker_loop(input_channel, output_channel,
                            observation_matrix, cholesky_decomposition,
                            nside, lmax, mmax, mrange, output_directory)
    while true
        try
            pixel = take!(input_channel)
            peak = getpsf_and_save(observation_matrix, cholesky_decomposition,
                                   nside, pixel, lmax, mmax, mrange, output_directory)
            put!(output_channel, peak)
        catch exception
            if isa(exception, RemoteException) || isa(exception, InvalidStateException)
                break
            else
                run(`hostname`)
                println(exception)
                rethrow(exception)
            end
        end
    end
end

function getpsf_and_save(observation_matrix, cholesky_decomposition,
                         nside, pixel, lmax, mmax, mrange, output_directory)
    θ, ϕ = LibHealpix.pix2ang_ring(nside, pixel)
    alm = getpsf(observation_matrix, cholesky_decomposition, θ, ϕ, lmax, mmax, mrange)
    map = alm2map(alm, nside)
    save(joinpath(output_directory, @sprintf("%08d.jld", pixel)), "alm", alm)
    map[pixel]
end

function getpsf(observation_matrix, cholesky_decomposition, θ, ϕ, lmax, mmax, mrange)
    input_alm = pointsource_alm(θ, ϕ, lmax, mmax)
    output_alm = observe(observation_matrix, cholesky_decomposition, input_alm)
    MModes.apply_wiener_filter!(output_alm, mrange)
    output_alm
end

function find_healpix_rings(nside)
    npix = nside2npix(nside)
    rings = Float64[]
    pixels = Int[]
    prg = Progress(npix÷4)
    for pixel = 1:4:npix
        θ, ϕ = LibHealpix.pix2ang_ring(nside, pixel)
        if !(θ in rings)
            push!(rings, θ)
            push!(pixels, pixel)
        end
        next!(prg)
    end
    pixels
end

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

function observe(observation_matrix, cholesky_decomposition, input_alm)
    output_alm = Alm(Complex128, lmax(input_alm), mmax(input_alm))
    for m = 0:mmax(input_alm)
        x = [input_alm[l, m] for l = m:lmax(input_alm)]
        y = observe_block(observation_matrix[m+1], cholesky_decomposition[m+1], x)
        for l = m:lmax(input_alm)
            output_alm[l, m] = y[l-m+1]
        end
    end
    output_alm
end

function observe_block(observation_matrix, cholesky_decomposition, input_alm)
    output_alm = similar(input_alm)
    A_mul_B!(output_alm, observation_matrix, input_alm)
    Ac_ldiv_B!(cholesky_decomposition, output_alm)
    A_ldiv_B!(cholesky_decomposition, output_alm)
    output_alm
end

#function getpeak(psfpeaks::PSFPeakValues, θ)
#    idx = searchsortedlast(psfpeaks.θ, θ)
#    psfpeaks.values[idx]
#end

