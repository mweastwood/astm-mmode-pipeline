function getpsf(spw, target; tolerance=0.01)
    dir = getdir(spw)
    transfermatrix = TransferMatrix(joinpath(dir, "transfermatrix"))
    flags = load(joinpath(dir, target*".jld"), "flags")
    getpsf(spw, transfermatrix, flags, tolerance)
end

function getpsf(spw, transfermatrix, flags, tolerance)
    dir = getdir(spw)
    psf_dir = joinpath(dir, "psf")
    isdir(psf_dir) || mkdir(psf_dir)

    for θ in reverse(linspace(0, 130, 27)) # every 5 degrees
        @show θ
        alm = _getpsf(transfermatrix, flags, deg2rad(θ), tolerance)
        psf = alm2map(alm, 512)
        output = @sprintf("psf%+03d-degrees.fits", round(Int, 90-θ))
        writehealpix(joinpath(psf_dir, output), psf, replace=true)
    end
end

function pointsource_alm(θ, ϕ, lmax, mmax)
    alm = Alm(Complex128, lmax, mmax)
    for m = 0:mmax, l = m:lmax
        alm[l,m] = conj(BPJSpec.Y(l, m, θ, ϕ))
    end
    alm
end

function _getpsf(transfermatrix, flags, θ, tolerance)
    lmax = transfermatrix.lmax
    mmax = transfermatrix.mmax
    input_alm = pointsource_alm(θ, 0.0, lmax, mmax)
    output_alm = Alm(Complex128, lmax, mmax)

    m = 0
    nextm() = (m′ = m; m += 1; m′)
    prg = Progress(mmax+1, "Progress: ")
    lck = ReentrantLock()
    increment_progress() = (lock(lck); next!(prg); unlock(lck))
    @sync for worker in workers()
        @async begin
            input_channel  = RemoteChannel()
            output_channel = RemoteChannel()
            try
                remotecall(getpsf_remote_processing_loop, worker, input_channel, output_channel,
                           transfermatrix, input_alm, flags, tolerance)
                Lumberjack.debug("Worker $worker has been started")
                while true
                    m′ = nextm()
                    m′ ≤ mmax || break
                    Lumberjack.debug("Worker $worker is processing m=$(m′)")
                    put!(input_channel, m′)
                    block = take!(output_channel)
                    for l = m′:lmax
                        output_alm[l, m′] = block[l-m′+1]
                    end
                    increment_progress()
                end
            finally
                close(input_channel)
                close(output_channel)
            end
        end
    end
    output_alm
end

function getpsf_remote_processing_loop(input, output, transfermatrix, alm, flags, tolerance)
    BLAS.set_num_threads(16) # compensate for a bug in `addprocs`
    lmax = transfermatrix.lmax
    mmax = transfermatrix.mmax
    while true
        try
            m = take!(input)
            A = transfermatrix[m, 1]
            x = zeros(Complex128, lmax-m+1)
            for l = m:lmax
                x[l-m+1] = alm[l, m]
            end
            f = flags[m+1]
            b = A*x
            A = A[!f, :]
            b = b[!f]
            x = tikhonov(A, b, tolerance)
            put!(output, x)
        catch exception
            if isa(exception, RemoteException) || isa(exception, InvalidStateException)
                # If this is a remote worker, we will see a RemoteException when the channel is
                # closed. However, if this is the master process (ie. we're running without any
                # workers) then this will be an InvalidStateException. This is kind of messy...
                break
            else
                println(exception)
                rethrow(exception)
            end
        end
    end
end

