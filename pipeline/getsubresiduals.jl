function getsubresiduals(spw)
    dir = getdir(spw)
    meta = getmeta(spw)
    meta.channels = meta.channels[55:55]
    sources = readsources(joinpath(sourcelists, "getdata-sources.json"))
    times, data, flags = load(joinpath(dir, "visibilities.jld"), "times", "data", "flags")
    Nbase, Ntime = size(data)

    fluxes = zeros(length(sources), Ntime)

    @show Nbase, Ntime
    for idx = 1:Ntime
        @show idx
        mydata = zeros(JonesMatrix, Nbase, 1)
        myflags = zeros(Bool, Nbase, 1)
        for α = 1:Nbase
            mydata[α] = JonesMatrix(data[α,idx], 0, 0, data[α,idx])
            myflags[α] = flags[α,idx]
        end

        meta.time = Epoch(epoch"UTC", times[idx]*seconds)
        frame = TTCal.reference_frame(meta)

        visibilities = Visibilities(mydata, myflags)
        flag_short_baselines!(visibilities, meta, 15.0)
        for (jdx, source) in enumerate(sources)
            TTCal.isabovehorizon(frame, source) || continue
            flux = TTCal.stokes(mean(getspec(visibilities, meta, source.direction))).I
            fluxes[jdx, idx] = flux
            @show source, flux
        end
    end

    save(joinpath(dir, "residual-fluxes.jld"), "fluxes", fluxes)

end

