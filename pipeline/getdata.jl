function getdata(spw)
    dadas = listdadas(spw)
    getdata(spw, 1:length(dadas))
end

function getdata(spw, range)
    dadas = listdadas(spw)[range]
    Ntime = length(range)
    meta = getmeta(spw)

    idx = 1
    nextidx() = (myidx = idx; idx += 1; myidx)

    p = Progress(Ntime)
    l = ReentrantLock()
    increment_progress() = (lock(l); next!(p); unlock(l))

    times = zeros(Ntime)
    phase = zeros(Float64, 2, Ntime) # the phase center (ra and dec)
    data = zeros(Complex128, 2, Nbase(meta), Ntime)

    @sync for worker in workers()
        @async begin
            input = RemoteChannel()
            output_time  = RemoteChannel()
            output_phase = RemoteChannel()
            output_data  = RemoteChannel()
            remotecall(getdata_worker_loop, worker, dadas,
                       input, output_time, output_phase, output_data)
            while true
                myidx = nextidx()
                myidx ≤ Ntime || break
                put!(input, myidx)
                times[myidx] = take!(output_time)
                phase[:, myidx] = take!(output_phase)
                data[:, :, myidx] = take!(output_data)
                increment_progress()
            end
            close(input)
            close(output_time)
            close(output_phase)
            close(output_data)
        end
    end

    dir = getdir(spw)
    output_file = joinpath(dir, "raw-visibilities.jld")
    save(output_file, "times", times, "phase", phase, "data", data, compress=true)

    nothing
end

function getdata_worker_loop(dadas, input, output_time, output_phase, output_data)
    while true
        try
            idx = take!(input)
            time, phase, data = getdata_do_the_work(dadas[idx])
            put!(output_time, time)
            put!(output_phase, phase)
            put!(output_data, data)
        catch exception
            if isa(exception, InvalidStateException)
                # channel was closed
                break
            else
                rethrow(exception)
            end
        end
    end
end

function getdata_do_the_work(dada)
    ms, path = dada2ms(dada)
    data = ms["DATA"]
    time = ms["TIME", 1]

    field = Table(ms[kw"FIELD"])
    phase = squeeze(field["PHASE_DIR", 1], 2)
    finalize(field)

    # discard the xy and yx correlations because we don't really have the information to calibrate
    # them (no polarization calibration)
    keep = [true; false; false; true]

    # discard all channels except the single channel we are interested in
    channel = 55

    output = data[keep, channel, :]

    finalize(ms)
    rm(path, recursive=true)

    time, phase, output
end

