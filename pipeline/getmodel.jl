function getmodel(spw, input="alm", output_mmodes="mmodes-model", output_vis="visibilities-model", Ntime = 6628)
    Lumberjack.info("Computing model visibilities for spectral window $spw")
    dir = getdir(spw)

    transfermatrix = TransferMatrix(joinpath(dir, "transfermatrix"))
    Lumberjack.info("Using transfer matrix $(transfermatrix.path)")

    path_to_alm = joinpath(dir, input*".jld")
    alm = load(path_to_alm, "alm")
    Lumberjack.info("Using spherical harmonic coefficients $path_to_alm")

    mmodes = MModes(joinpath(dir, output_mmodes), transfermatrix.mmax, transfermatrix.frequencies)
    Lumberjack.info("Saving model m-modes to $(mmodes.path)")
    _getmodel(transfermatrix, alm, mmodes)

    meta = getmeta(spw)
    path_to_visibilities = joinpath(dir, output_vis)
    Lumberjack.info("Saving model visibilities to $(path_to_visibilities)")
    visibilities = GriddedVisibilities(path_to_visibilities, meta, mmodes, Ntime)
end

function _getmodel(transfermatrix::TransferMatrix, alm, mmodes)
    lmax = transfermatrix.lmax
    mmax = transfermatrix.mmax
    m = 0
    nextm() = (m′ = m; m += 1; m′)
    p = Progress(mmax+1, "Progress: ")
    l = ReentrantLock()
    increment_progress() = (lock(l); next!(p); unlock(l))
    @sync for worker in workers()
        @async begin
            input_channel  = RemoteChannel()
            output_channel = RemoteChannel()
            try
                remotecall(getmodel_remote_processing_loop, worker, input_channel, output_channel, transfermatrix, alm)
                Lumberjack.debug("Worker $worker has been started")
                while true
                    m′ = nextm()
                    m′ ≤ mmax || break
                    Lumberjack.debug("Worker $worker is processing m=$(m′)")
                    put!(input_channel, m′)
                    block = take!(output_channel)
                    mmodes[m′,1] = block
                    increment_progress()
                end
            finally
                close(input_channel)
                close(output_channel)
            end
        end
    end
    nothing
end

function getmodel_remote_processing_loop(input, output, transfermatrix, alm)
    BLAS.set_num_threads(16) # compensate for a bug in `addprocs`
    lmax = transfermatrix.lmax
    mmax = transfermatrix.mmax
    while true
        m = take!(input)
        A = transfermatrix[m,1]
        x = zeros(Complex128, lmax-m+1)
        for l = m:lmax
            x[l-m+1] = alm[l,m]
        end
        b = A*x
        put!(output, b)
    end
end

