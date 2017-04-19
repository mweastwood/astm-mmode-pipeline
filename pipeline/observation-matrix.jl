function observation_matrix(spw, dataset="rainy")
    dir = getdir(spw)
    transfermatrix = TransferMatrix(joinpath(dir, "transfermatrix"))
    flags = load(joinpath(dir, "mmodes-rfi-subtracted-peeled-$dataset.jld"), "flags")
    tolerance = load(joinpath(dir, "alm-rfi-subtracted-peeled-$dataset.jld"), "tolerance")
    blocks = observation_matrix(spw, transfermatrix, flags, tolerance)
    save(joinpath(dir, "observation-matrix-$dataset.jld"),
         "blocks", blocks, "flags", flags, "tolerance", tolerance,
         "lmax", transfermatrix.lmax, "mmax", transfermatrix.mmax)
end

function observation_matrix(spw, transfermatrix, flags, tolerance)
    lmax = transfermatrix.lmax
    mmax = transfermatrix.mmax
    blocks = Vector{Matrix{Complex128}}(mmax+1)

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
                remotecall(observation_matrix_remote_processing_loop, worker, input_channel, output_channel,
                           transfermatrix, flags, tolerance)
                Lumberjack.debug("Worker $worker has been started")
                while true
                    m′ = nextm()
                    m′ ≤ mmax || break
                    Lumberjack.debug("Worker $worker is processing m=$(m′)")
                    put!(input_channel, m′)
                    block = take!(output_channel)
                    blocks[m′+1] = block
                    increment_progress()
                end
            finally
                close(input_channel)
                close(output_channel)
            end
        end
    end
    blocks
end

function observation_matrix_remote_processing_loop(input, output, transfermatrix, flags, tolerance)
    BLAS.set_num_threads(16) # compensate for a bug in `addprocs`
    lmax = transfermatrix.lmax
    mmax = transfermatrix.mmax
    while true
        try
            m = take!(input)
            B = transfermatrix[m, 1]
            f = flags[m+1]
            Bf = B[!f, :]
            D = tolerance*I
            BB = Bf'*Bf
            BBD = BB + D
            block = BBD\BB
            put!(output, block)
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

