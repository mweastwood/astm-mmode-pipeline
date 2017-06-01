function getalm(spw, dataset, target; tolerance=0.01)
    dir = getdir(spw)
    mmodes, mmode_flags = load(joinpath(dir, "$target-$dataset.jld"), "blocks", "flags")
    getalm(spw, mmodes, mmode_flags, dataset, target, tolerance=tolerance)
end

function getalm(spw, mmodes, mmode_flags, dataset, target; tolerance=0.01)
    dir = getdir(spw)
    alm = _getalm(spw, mmodes, mmode_flags, tolerance=tolerance)
    target = replace(target, "mmodes", "alm")
    save(joinpath(dir, "$target-$dataset.jld"), "alm", alm, "tolerance", tolerance)
    alm
end

function _getalm(spw::Int, mmodes, mmode_flags; tolerance=0.01)
    dir = getdir(spw)
    transfermatrix = TransferMatrix(joinpath(dir, "transfermatrix"))
    _getalm(transfermatrix, mmodes, mmode_flags, tolerance)
end

function _getalm(transfermatrix::TransferMatrix, mmodes, mmode_flags, tolerance)
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
                remotecall(getalm_remote_processing_loop, worker, input_channel, output_channel,
                           transfermatrix, mmodes, mmode_flags, tolerance)
                while true
                    m′ = nextm()
                    m′ ≤ mmax || break
                    put!(input_channel, m′)
                    block = take!(output_channel)
                    for l = m′:lmax
                        alm[l, m′] = block[l-m′+1]
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

function getalm_remote_processing_loop(input, output, transfermatrix, mmodes, mmode_flags, tolerance)
    BLAS.set_num_threads(16) # compensate for a bug in `addprocs`
    local m
    while true
        try
            m = take!(input)
            A = transfermatrix[m, 1]
            b = mmodes[m+1]
            f = mmode_flags[m+1]
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
                @show m
                run(`hostname`)
                println(exception)
                rethrow(exception)
            end
        end
    end
end

