function peel(spw, times, data, flags)
    Ntime = length(times)
    idx = 1
    nextidx() = (myidx = idx; idx += 1; myidx)

    p = Progress(Ntime)
    l = ReentrantLock()
    increment_progress() = (lock(l); next!(p); unlock(l))

    @sync for worker in workers()
        @async begin
            input  = RemoteChannel()
            output = RemoteChannel()
            remotecall(peel_worker_loop, worker, spw, input, output)
            while true
                myidx = nextidx()
                myidx ≤ Ntime || break
                put!(input, (times[myidx], data[:, :, myidx], flags[:, myidx]))
                data[:, :, myidx], flags[:, myidx] = take!(output)
                increment_progress()
            end
            close(input)
            close(output)
        end
    end

    dir = getdir(spw)
    output_file = joinpath(dir, "peeled-visibilities.jld")
    save(output_file, "times", times, "data", data, "flags", flags, compress=true)
end

function peel_worker_loop(spw, input, output)
    dir = getdir(spw)
    meta = getmeta(spw)
    xx_rfi, yy_rfi = load(joinpath(dir, "rfi-components.jld"), "xx", "yy")
    while true
        try
            time, data, flags = take!(input)
            peel_do_the_work(time, data, flags, dir, meta, xx_rfi, yy_rfi)
            put!(output, (data, flags))
        catch exception
            if isa(exception, InvalidStateException)
                # channel was closed
                break
            else
                println(exception)
                rethrow(exception)
            end
        end
    end
end

function peel_do_the_work(time, data, flags, dir, meta, xx_rfi, yy_rfi)
    xx = data[1, :]
    yy = data[2, :]

    # flag the auto correlations
    for ant = 1:Nant(meta)
        α = baseline_index(ant, ant)
        flags[α] = true
    end

    # remove the RFI
    xx, yy = rm_rfi(flags, xx, yy, xx_rfi, yy_rfi)

    data[1, :] = xx
    data[2, :] = yy
end

function rm_rfi(flags, xx, yy, xx_rfi, yy_rfi)
    if !all(flags)
        xx_flagged = xx[!flags]
        yy_flagged = yy[!flags]
        xx_rfi_flagged = xx_rfi[!flags, :]
        yy_rfi_flagged = yy_rfi[!flags, :]
        xx_flux = xx_rfi_flagged \ xx_flagged
        yy_flux = yy_rfi_flagged \ yy_flagged
        xx -= xx_rfi * xx_flux
        yy -= yy_rfi * yy_flux
    end
    xx, yy
end

#function peel_pick_sources(spw, data)
#    A = TTCal.Source[]
#    B = TTCal.Source[]
#    fluxes = Float64[]
#    for source in sources
#        flux = StokesVector(TTCal.get_total_flux(source, ν)).I
#        flux > 30 || continue
#        if source.name == "Cyg A" || source.name == "Cas A"
#            if TTCal.isabovehorizon(frame, source, deg2rad(10))
#                push!(A, source)
#                push!(fluxes, flux)
#            else
#                push!(B, source)
#            end
#        elseif source.name == "Vir A"# || source.name == "Tau A"
#            if TTCal.isabovehorizon(frame, source, deg2rad(45))
#                push!(A, source)
#                push!(fluxes, flux)
#            else
#                push!(B, source)
#            end
#        else
#            push!(B, source)
#        end
#    end
#    perm = sortperm(fluxes, rev=true)
#    A = A[perm]
#    A, B
#end

