function getmodel(spw, Ntime=6628)
    dir = getdir(spw)
    transfermatrix = TransferMatrix(joinpath(dir, "transfermatrix"))
    alm = load(joinpath(dir, "alm.jld"), "alm")
    mmodes = getmodel_mmodes(transfermatrix, alm)
    save(joinpath(dir, "model-mmodes.jld"), "blocks", mmodes, compress=true)
    visibilities = getmodel_visibilities(mmodes, Ntime)
    save(joinpath(dir, "model-visibilities.jld"), "data", visibilities, compress=true)
end

function getmodel_mmodes(transfermatrix, alm)
    lmax = transfermatrix.lmax
    mmax = transfermatrix.mmax
    mmodes = Vector{Vector{Complex128}}(mmax+1)
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
                remotecall(getmodel_mmodes_remote_processing_loop, worker, input_channel, output_channel,
                           transfermatrix, alm)
                Lumberjack.debug("Worker $worker has been started")
                while true
                    m′ = nextm()
                    m′ ≤ mmax || break
                    Lumberjack.debug("Worker $worker is processing m=$(m′)")
                    put!(input_channel, m′)
                    block = take!(output_channel)
                    mmodes[m′+1] = block
                    increment_progress()
                end
            finally
                close(input_channel)
                close(output_channel)
            end
        end
    end
    mmodes
end

function getmodel_mmodes_remote_processing_loop(input, output, transfermatrix, alm)
    BLAS.set_num_threads(16) # compensate for a bug in `addprocs`
    lmax = transfermatrix.lmax
    mmax = transfermatrix.mmax
    while true
        try
            m = take!(input)
            A = transfermatrix[m, 1]
            x = zeros(Complex128, lmax-m+1)
            for l = m:lmax
                x[l-m+1] = alm[l,m]
            end
            b = A*x
            put!(output, b)
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

function getmodel_visibilities(mmodes, Ntime)
    Nbase = length(mmodes[1])
    matrix = zeros(Complex128, Nbase, Ntime)
    pack_matrix!(matrix, mmodes)
    visibilities = do_inverse_fourier_transform(matrix)
    visibilities
end

function pack_matrix!(matrix, mmodes)
    Nbase, Ntime = size(matrix)
    mmax = length(mmodes)-1
    for m = 0:mmax
        block = mmodes[m+1]
        if m == 0
            for α = 1:Nbase
                matrix[α, 1] = block[α]
            end
        else
            for α = 1:Nbase
                α1 = 2α - 1 # positive m
                α2 = 2α - 0 # negative m
                matrix[α, m+1] = block[α1]
                matrix[α, Ntime+1-m] = conj(block[α2])
            end
        end
    end
end

function do_inverse_fourier_transform(matrix)
    Nbase, Ntime = size(matrix)
    FFTW.set_num_threads(16)
    transposed = permutedims(matrix, (2, 1)) # put time on the fast axis
    planned_ifft = plan_ifft(transposed, 1)
    fourier = planned_ifft * transposed * Ntime
    permutedims(fourier, (2, 1)) # undo the previous transpose
end

