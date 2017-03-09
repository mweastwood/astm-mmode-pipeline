function getalm(spw, target="mmodes-peeled"; tolerance=0.01)
    dir = getdir(spw)
    mmodes, mmode_flags = load(joinpath(dir, target*".jld"), "blocks", "flags")
    getalm(spw, mmodes, mmode_flags, target, tolerance=tolerance)
end

function getalm(spw, mmodes, mmode_flags, target; tolerance=0.01, pass=1)
    dir = getdir(spw)
    transfermatrix = TransferMatrix(joinpath(dir, "transfermatrix"))
    alm = _getalm(transfermatrix, mmodes, mmode_flags, tolerance)
    output = replace(target, "mmodes", "alm")
    save(joinpath(dir, output*".jld"), "alm", alm, "tolerance", tolerance)
    alm
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
                Lumberjack.debug("Worker $worker has been started")
                while true
                    m′ = nextm()
                    m′ ≤ mmax || break
                    Lumberjack.debug("Worker $worker is processing m=$(m′)")
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
    while true
        try
            m = take!(input)
            A = transfermatrix[m, 1]
            b = mmodes[m+1]
            f = mmode_flags[m+1]
            #prototype_additional_baseline_flags!(f, m)
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

macro fl(ant1, ant2)
    quote
        push!(list, ($ant1, $ant2))
    end |> esc
end

function prototype_additional_baseline_flags!(f, m)
    list = Tuple{Int, Int}[]
    @fl 147 174
    @fl 13 57
    @fl 53 57
    @fl 122 125
    @fl 122 126
    @fl 122 127
    @fl 123 126
    @fl 123 127
    @fl 123 128
    @fl 124 127
    @fl 125 128
    @fl 147 174
    @fl 185 192
    @fl 189 192
    @fl 240 244
    @fl 243 246
    for (ant1, ant2) in list
        α = baseline_index(ant1, ant2)
        if m == 0
            f[α] = true
        else
            f[2α - 1] = true
            f[2α - 0] = true
        end
    end
end

