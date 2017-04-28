function subrfi(spw, dataset, target)
    dir = getdir(spw)
    times, data, flags = load(joinpath(dir, "$target-$dataset-visibilities.jld"),
                              "times", "data", "flags")
    subrfi(spw, times, data, flags, dataset, target)
end

function subrfi(spw, times, data, flags, dataset, target)
    Ntime = size(data, 3)
    idx = 1
    nextidx() = (myidx = idx; idx += 1; myidx)

    p = Progress(Ntime)
    l = ReentrantLock()
    increment_progress() = (lock(l); next!(p); unlock(l))

    dir = getdir(spw)
    xx_rfi, yy_rfi = load(joinpath(dir, "fitrfi-$dataset-$target.jld"), "xx", "yy")
    Nrfi = size(xx_rfi, 2)
    Ntime = size(data, 3)
    xx_rfi_flux = zeros(Nrfi, Ntime)
    yy_rfi_flux = zeros(Nrfi, Ntime)
    @sync for worker in workers()
        @async begin
            input  = RemoteChannel()
            output = RemoteChannel()
            remotecall(subrfi_worker_loop, worker, spw, input, output, xx_rfi, yy_rfi)
            while true
                myidx = nextidx()
                myidx ≤ Ntime || break
                put!(input, (times[myidx], data[:, :, myidx], flags[:, myidx]))
                data[:, :, myidx], xx_rfi_flux[:, myidx], yy_rfi_flux[:, myidx] = take!(output)
                increment_progress()
            end
            close(input)
            close(output)
        end
    end

    output_file = joinpath(dir, "rfi-subtracted-$target-$dataset-visibilities.jld")
    isfile(output_file) && rm(output_file)
    save(output_file, "times", times, "data", data, "flags", flags,
         "xx-rfi-flux", xx_rfi_flux, "yy-rfi-flux", yy_rfi_flux, compress=true)

    data, flags
end

function subrfi_worker_loop(spw, input, output, xx_rfi, yy_rfi)
    dir = getdir(spw)
    meta = getmeta(spw)
    meta.channels = meta.channels[55:55]
    meta.phase_center = Direction(dir"AZEL", 0degrees, 90degrees)
    while true
        try
            time, data, flags = take!(input)
            data, xx_rfi_flux, yy_rfi_flux = subrfi_do_the_work(meta, data, flags, xx_rfi, yy_rfi)
            put!(output, (data, xx_rfi_flux, yy_rfi_flux))
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

function subrfi_do_the_work(meta, data, flags, xx_rfi, yy_rfi)
    Nbase = length(flags)
    frame = TTCal.reference_frame(meta)
    visibilities = Visibilities(Nbase, 1)
    visibilities.flags[:] = true
    for α = 1:Nbase
        visibilities.data[α, 1] = JonesMatrix(data[1, α], 0, 0, data[2, α])
        visibilities.flags[α, 1] = flags[α]
    end

    # apply some additional flags
    TTCal.flag_short_baselines!(visibilities, meta, 15.0)

    xx = getfield.(visibilities.data[:, 1], 1)
    yy = getfield.(visibilities.data[:, 1], 4)
    flags = visibilities.flags[:, 1]
    for ant = 1:Nant(meta)
        α = baseline_index(ant, ant)
        flags[α] = true
    end
    xx, yy, xx_rfi_flux, yy_rfi_flux = rm_rfi(flags, xx, yy, xx_rfi, yy_rfi)
    data[1, :] = xx
    data[2, :] = yy
    data, xx_rfi_flux, yy_rfi_flux
end

function rm_rfi(flags, xx, yy, xx_rfi, yy_rfi)
    # TODO: I'm getting extremely small amplitudes for xx_rfi_flux and yy_rfi_flux. I'm not entirely
    # sure what's going on. I should also think about constraining these to be real. At the moment
    # I'm just letting them be complex.
    if !all(flags)
        xx_flagged = xx[!flags]
        yy_flagged = yy[!flags]
        xx_rfi_flagged = xx_rfi[!flags, :]
        yy_rfi_flagged = yy_rfi[!flags, :]
        xx_flagged = [xx_flagged; conj(xx_flagged)]
        yy_flagged = [yy_flagged; conj(yy_flagged)]
        xx_rfi_flagged = [xx_rfi_flagged; conj(xx_rfi_flagged)]
        yy_rfi_flagged = [yy_rfi_flagged; conj(yy_rfi_flagged)]
        xx_rfi_flux = real(xx_rfi_flagged \ xx_flagged)
        yy_rfi_flux = real(yy_rfi_flagged \ yy_flagged)
        xx -= xx_rfi * xx_rfi_flux
        yy -= yy_rfi * yy_rfi_flux
    else
        N = size(xx_rfi, 2) # the number of RFI sources
        xx_rfi_flux = zeros(N)
        yy_rfi_flux = zeros(N)
    end
    xx, yy, xx_rfi_flux, yy_rfi_flux
end

function rm_rfi(meta::Metadata, visibilities::Visibilities, sources, calibrations)
    # this method is used by fitrfi to subtract RFI from a preliminary integration
    xx = getfield.(visibilities.data[:, 1], 1)
    yy = getfield.(visibilities.data[:, 1], 4)
    data = zeros(Complex128, 2, length(xx))
    data[1, :] = xx
    data[2, :] = yy
    flags = visibilities.flags[:, 1]

    N = length(sources)
    xx_rfi = zeros(Complex128, Nbase(meta), N)
    yy_rfi = zeros(Complex128, Nbase(meta), N)
    beam = ConstantBeam()
    for idx = 1:N
        model = genvis(meta, beam, sources[idx])
        corrupt!(model, meta, calibrations[idx])
        for α = 1:Nbase(meta)
            xx_rfi[α, idx] = model.data[α, 1].xx
            yy_rfi[α, idx] = model.data[α, 1].yy
        end
    end

    data, xx_rfi_flux, yy_rfi_flux = subrfi_do_the_work(meta, data, flags, xx_rfi, yy_rfi)

    for α = 1:Nbase(meta)
        visibilities.data[α, 1] = JonesMatrix(data[1, α], 0, 0, data[2, α])
    end
    visibilities
end

