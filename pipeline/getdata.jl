function getdata(spw, dataset="100hr")
    spw = fix_spw_offset(spw, dataset)
    dadas = listdadas(spw, dataset)
    getdata(spw, 1:length(dadas), dataset)
end

function getdata(spw, range, dataset)
    dadas = listdadas(spw)[range]
    Ntime = length(range)
    meta = getmeta(spw)

    idx = 1
    nextidx() = (myidx = idx; idx += 1; myidx)

    p = Progress(Ntime)
    l = ReentrantLock()
    increment_progress() = (lock(l); next!(p); unlock(l))

    times = zeros(Ntime)
    data = zeros(Complex128, 2, Nbase(meta), Ntime)

    @sync for worker in workers()
        @async begin
            input = RemoteChannel()
            output = RemoteChannel()
            remotecall(getdata_worker_loop, worker, dataset, dadas, input, output)
            while true
                myidx = nextidx()
                myidx ≤ Ntime || break
                put!(input, myidx)
                times[myidx], data[:, :, myidx] = take!(output)
                increment_progress()
            end
            close(input)
            close(output)
        end
    end

    dir = getdir(spw)
    output_file = joinpath(dir, "raw-$dataset-visibilities.jld")
    save(output_file, "times", times, "data", data, compress=true)

    nothing
end

function getdata_worker_loop(dataset, dadas, input, output)
    while true
        try
            idx = take!(input)
            time, data = getdata_do_the_work(dataset, dadas[idx])
            put!(output, (time, data))
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

function getdata_do_the_work(dataset, dada)
    local time, output
    try
        ms, path = dada2ms(dada, swap_polarizations=are_pols_swapped(dataset))
        data = ms["DATA"] :: Array{Complex64, 3}
        time = ms["TIME", 1] :: Float64

        # discard the xy and yx correlations because we don't really have the information to
        # calibrate them (no polarization calibration)
        keep = [true; false; false; true]

        # discard all channels except the single channel we are interested in
        channel = 55

        output = data[keep, channel, :]
        finalize(ms)
        rm(path, recursive=true)
    catch exception
        println(dada)
        println(exception)
        # we will indicate that this integration should be flagged by setting the time to something
        # absurd (ie. negative)
        output = zeros(Complex64, 2, Nant2Nbase(256))
        time = -1.0
    end
    time, output
end

