function getalm(spw, input="mmodes", output="alm", tolerance=0.05)
    Lumberjack.info("Computing spherical harmonic coefficients for spectral window $spw")
    dir = getdir(spw)
    transfermatrix = TransferMatrix(joinpath(dir, "transfermatrix"))
    mmodes = MModes(joinpath(dir, input))
    Lumberjack.info("Using transfer matrix $(transfermatrix.path)")
    Lumberjack.info("Using m-modes $(mmodes.path)")
    alm = _getalm(transfermatrix, mmodes, tolerance)
    output = joinpath(dir, output*".jld")
    Lumberjack.info("Saving the spherical harmonic coefficients to $output")
    save(output, "alm", alm)
end

function _getalm(transfermatrix::TransferMatrix, mmodes, tolerance)
    lmax = transfermatrix.lmax
    mmax = transfermatrix.mmax
    alm = Alm(Complex128, lmax, mmax)
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
                remotecall(getalm_remote_processing_loop, worker, input_channel, output_channel, transfermatrix, mmodes, tolerance)
                Lumberjack.debug("Worker $worker has been started")
                while true
                    m′ = nextm()
                    m′ ≤ mmax || break
                    Lumberjack.debug("Worker $worker is processing m=$(m′)")
                    put!(input_channel, m′)
                    block = take!(output_channel)
                    for l = m′:lmax
                        alm[l,m′] = block[l-m′+1]
                    end
                    increment_progress()
                end
            finally
                close(input_channel)
                close(output_channel)
            end
        end
    end
    alm
end

function getalm_remote_processing_loop(input, output, transfermatrix, mmodes, tolerance)
    BLAS.set_num_threads(16) # compensate for a bug in `addprocs`
    while true
        m = take!(input)
        A = transfermatrix[m,1]
        b = mmodes[m,1]
        BPJSpec.account_for_flags!(A, b)
        x = tikhonov(A, b, tolerance)
        put!(output, x)
    end
end

