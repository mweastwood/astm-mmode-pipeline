function getalm(spw, dataset, target)
    dir = getdir(spw)
    mmodes, mmode_flags = load(joinpath(dir, "$target-$dataset.jld"), "blocks", "flags")
    #flag_short_baselines!(spw, mmode_flags)
    #flag_arx_boards!(spw, mmode_flags)
    getalm(spw, mmodes, mmode_flags, dataset, target, tolerance=select_tolerance(spw))
end

function select_tolerance(spw)
    #if spw == 4
    #    return 0.009771241535346501
    #elseif spw == 6
    #    return 0.013509935211980264
    #elseif spw == 8
    #    return 0.007663410868007455
    #elseif spw == 10
    #    return 0.005542664520663107
    #elseif spw == 12
    #    return 0.005111433483440166
    #elseif spw == 14
    #    return 0.004713753134116724
    #elseif spw == 16
    #    return 0.004347013158125026
    #elseif spw == 18
    #    #return 0.004008806328898464
    #    return 0.01
    #end
    0.01
end

function flag_short_baselines!(spw, mmode_flags)
    mmax = length(mmode_flags) - 1
    meta = getmeta(spw, "rainy")
    ν = meta.channels[55]

    b = zeros(Nbase(meta))
    for α = 1:Nbase(meta)
        antenna1 = meta.antennas[meta.baselines[α].antenna1]
        antenna2 = meta.antennas[meta.baselines[α].antenna2]
        u = antenna1.position.x - antenna2.position.x
        v = antenna1.position.y - antenna2.position.y
        w = antenna1.position.z - antenna2.position.z
        b[α] = sqrt(u^2 + v^2 + w^2)
    end

    bmin = minimum(b[b .!= 0]) * (73.152e6/ν)
    @show bmin
    for α = 1:Nbase(meta)
        if b[α] < bmin
            mmode_flags[1][α] = true
            for m = 1:mmax
                mmode_flags[m+1][2α-1] = true
                mmode_flags[m+1][2α-0] = true
            end
        end
    end

end

function flag_arx_boards!(spw, mmode_flags)
    mmax = length(mmode_flags) - 1
    meta = getmeta(spw, "rainy")
    for α = 1:Nbase(meta)
        antenna1 = meta.baselines[α].antenna1
        antenna2 = meta.baselines[α].antenna2
        if (antenna1-1)÷8 == (antenna2-1)÷8
            @show antenna1, antenna2
            mmode_flags[1][α] = true
            for m = 1:mmax
                mmode_flags[m+1][2α-1] = true
                mmode_flags[m+1][2α-0] = true
            end
        end
    end
end

function getalm(spw, mmodes, mmode_flags, dataset, target; tolerance=0.01)
    dir = getdir(spw)
    alm = _getalm(spw, mmodes, mmode_flags, tolerance=tolerance)
    target = replace(target, "mmodes", "alm")
    save(joinpath(dir, "target-$dataset.jld"), "alm", alm, "tolerance", tolerance)
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

