function lcurve(spw, dataset)
    _lcurve(spw, "mmodes-rfi-subtracted-peeled-$dataset.jld")
end

function _lcurve(spw, input_filename)
    dir = getdir(spw)
    transfermatrix = TransferMatrix(joinpath(dir, "transfermatrix"))
    mmodes, mmode_flags = load(joinpath(dir, input_filename), "blocks", "flags")
    _lcurve(spw, transfermatrix, mmodes, mmode_flags)
end

function _lcurve(spw, transfermatrix, mmodes, mmode_flags)
    trials  = logspace(2, -5, 50)
    lsnorm_squared  = zeros(length(trials)) # the value of the least-squares norm squared
    regnorm_squared = zeros(length(trials)) # the value of the regularizing norm squared

    function accumulate(output)
        for idx = 1:length(trials)
            lsnorm_squared[idx]  += output[1][idx]
            regnorm_squared[idx] += output[2][idx]
        end
    end

    m = 0
    mmax = transfermatrix.mmax
    nextm() = (m′ = m; m += 1; m′)
    prg = Progress(mmax+1, "Progress: ")
    lck = ReentrantLock()
    increment_progress() = (lock(lck); next!(prg); unlock(lck))
    @sync for worker in workers()
        @async begin
            input_channel  = RemoteChannel()
            output_channel = RemoteChannel()
            try
                remotecall(lcurve_remote_processing_loop, worker, input_channel, output_channel,
                           transfermatrix, mmodes, mmode_flags, trials)
                while true
                    m′ = nextm()
                    m′ ≤ mmax || break
                    put!(input_channel, m′)
                    accumulate(take!(output_channel))
                    increment_progress()
                end
            finally
                close(input_channel)
                close(output_channel)
            end
        end
    end

    trials, sqrt(lsnorm_squared), sqrt(regnorm_squared)
end

function lcurve_remote_processing_loop(input, output, transfermatrix, mmodes, mmode_flags, trials)
    BLAS.set_num_threads(16) # compensate for a bug in `addprocs`
    while true
        try
            m = take!(input)
            B = transfermatrix[m, 1]
            v = mmodes[m+1]
            f = mmode_flags[m+1]
            lsnorm_squared, regnorm_squared = lcurve_do_the_work(B, v, f, trials)
            put!(output, (lsnorm_squared, regnorm_squared))
        catch exception
            if isa(exception, RemoteException) || isa(exception, InvalidStateException)
                break
            else
                println(exception)
                rethrow(exception)
            end
        end
    end
end

function lcurve_do_the_work(B, v, f, trials)
    N = length(trials)
    lsnorm_squared  = zeros(N)
    regnorm_squared = zeros(N)

    B = B[!f, :]
    v = v[!f]
    BB = B'*B
    Bv = B'*v
    for idx = 1:N
        ϵ = trials[idx]
        a = (BB + ϵ*I)\Bv
        δv = v-B*a
        lsnorm_squared[idx] = norm(δv)^2
        regnorm_squared[idx] = norm(a)^2
    end

    lsnorm_squared, regnorm_squared
end

