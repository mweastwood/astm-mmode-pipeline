function rm_sun(spw, dataset, times, data, flags, sun_data, istest=false)
    restored_data = data + sun_data

    if spw == 14
        # NOTE: the process of writing to disk seems to drop enough precision to make a
        # difference...
        #sources = readsources(joinpath(dirname(@__FILE__), "..", "..", "workspace", "source-lists",
        #                               "sun-spw14-2017-07-18T09:40:40.134.json"))
        #sun = sources[1]
        x0 = [1622.2669729386591, 2293.413730331039, -20.0493648229423,
              -0.13658950102982556, -0.0015192147751638962, -0.014392339908425792, -0.005765899007730887,
              -0.047316905221074665, 0.04824140333473242,    0.10639368298705491,  -0.00761371053942145,
               0.02182254648237799, -0.007500232542486043,   0.06014367076653129,   0.0026133957685073057,
               0.005094455449773894, 0.0002991638049416478, -0.026020631618510058, -0.0010620435723069604]
        sun = getsun_construct_model(x0)
    else
        sources = readsources(joinpath(dirname(@__FILE__), "..", "..", "workspace", "source-lists",
                                       "getdata-sources.json"))
        filter!(source->source.name == "Sun", sources)
        sun = sources[1]
    end

    idx = 1
    Ntime = length(times)
    nextidx() = (myidx = idx; idx += 1; myidx)

    p = Progress(length(idx:Ntime))
    l = ReentrantLock()
    increment_progress() = (lock(l); next!(p); unlock(l))

    Nbase = size(data, 2)
    output_data = zeros(Complex128, 2, Nbase)
    output_flags = ones(Bool, Nbase)

    @sync for worker in workers()
        @async while true
            integration = nextidx()
            integration ≤ Ntime || break
            mytime = times[integration]
            mydata = restored_data[:, :, integration]
            myflags = flags[:, integration]
            mydata = remotecall_fetch(rm_sun_worker, worker,
                                      spw, mytime, mydata, myflags, sun)
            restored_data[:, :, integration] = mydata
            increment_progress()
        end
    end

    restored_data
end

function rm_sun_worker(spw, time, data, flags, sun)
    meta = getmeta(spw, "rainy")
    meta.channels = meta.channels[55:55]
    meta.phase_center = Direction(dir"AZEL", 0degrees, 90degrees)
    meta.time = Epoch(epoch"UTC", time*seconds)
    frame = TTCal.reference_frame(meta)

    visibilities = Visibilities(Nbase(meta), 1)
    for α = 1:Nbase(meta)
        visibilities.data[α, 1] = JonesMatrix(data[1, α], 0, 0, data[2, α])
        visibilities.flags[α, 1] = flags[α]
    end
    TTCal.flag_short_baselines!(visibilities, meta, 15.0)

    if TTCal.isabovehorizon(frame, sun, deg2rad(15))
        start_I = getflux(visibilities, meta, sun)
        calibrations = peel!(visibilities, meta, ConstantBeam(), [sun],
                             peeliter=1, maxiter=100, tolerance=1e-3, quiet=true)
        calibration = calibrations[1]

        model = genvis(meta, sun)
        corrupt!(model, meta, calibration)
        removed_I = getflux(model, meta, sun)
        if abs(removed_I) < 0.9*abs(start_I)
            putsrc!(visibilities, model)
            sun = fit_source_with_shapelets(meta, visibilities, sun)
            subsrc!(visibilities, meta, ConstantBeam(), sun)
        end
    elseif TTCal.isabovehorizon(frame, sun)
        sun = fit_source_with_shapelets(meta, visibilities, sun)
        subsrc!(visibilities, meta, ConstantBeam(), sun)
    end

    xx = getfield.(visibilities.data[:, 1], 1)
    yy = getfield.(visibilities.data[:, 1], 4)
    data[1, :] = xx
    data[2, :] = yy
    data
end

#    #if !TTCal.isabovehorizon(frame, sun, deg2rad(15))
#    #   sun = fit_source_with_shapelets(meta, visibilities, sun)
#    #   subsrc!(visibilities, meta, ConstantBeam(), sun)
#    #else
#        start_I = getflux(visibilities, meta, sun)
#        calibrations = peel!(visibilities, meta, ConstantBeam(), [sun],
#                             peeliter=1, maxiter=100, tolerance=1e-3, quiet=!istest)
#        #calibration = calibrations[1]
#
#        #model = genvis(meta, sun)
#        #corrupt!(model, meta, calibration)
#        #removed_I = getflux(model, meta, sun)
#        #if abs(removed_I) < 0.9*abs(start_I)
#        #    putsrc!(visibilities, model)
#        #    sun = fit_source_with_shapelets(meta, visibilities, sun)
#        #    subsrc!(visibilities, meta, ConstantBeam(), sun)
#        #end
#    #end

