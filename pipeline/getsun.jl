function getsun()
    Lumberjack.info("Fitting a model of the Sun")
    spw = 18
    dir = getdir(spw)
    times, data, flags, peeling_data = load(joinpath(dir, "peeled-rainy-visibilities.jld"),
                                            "times", "data", "flags", "peeling-data")
    getsun(spw, times, data, flags, peeling_data)
end

function getsun(spw, times, data, flags, peeling_data)
    integrations = 1850:2750
    times = times[integrations]
    data = data[:, :, integrations]
    flags = flags[:, integrations]
    peeling_data = peeling_data[integrations]

    Lumberjack.info("* Restoring the Sun")
    restore_the_sun!(spw, times, data, flags, peeling_data)

    function residual(x, g)
        println("=====")
        @show x
        sun = getsun_construct_model(x)
        @show sun
        Lumberjack.info("* Peeling the Sun")
        summed_data, summed_flags = getsun_residual_visibilities(spw, times, data, flags, sun)
        Lumberjack.info("* Imaging the residuals")
        output = getsun_residual_image(spw, summed_data, summed_flags)
        @show output
        output
    end

    N = 4^2
    #x0 = zeros(N)
    x0 = [-0.1510759761698713,
          -0.02066199368032352,
          -0.018493304474277106,
          -0.0012873111106452735,
          -0.036009230301391706,
          0.00016816926519434334,
          0.10053548515299322,
          -0.0012698942453968239,
          0.009018968911481295,
          -0.005032715278400886,
          0.06749641456795911,
          0.0002023066369522653,
          0.0017188608486568857,
          0.001160116390556377,
          -0.02489101087535827,
          0.00010983142769303976]
    xmin = -ones(N)
    xmax = +ones(N)


    #opt = Opt(:LN_SBPLX, length(x0))
    #ftol_rel!(opt, 1e-3)
    #min_objective!(opt, residual)
    #lower_bounds!(opt, xmin)
    #upper_bounds!(opt, xmax)
    #minf, x, ret = optimize(opt, x0)
    #println("++++")
    #println("DONE")
    #@show minf, x, ret
    x = x0

    residual(x, [])
    for y in x
       println(y)
    end

    output = joinpath(sourcelists, "sun-$(now()).json")
    sun = getsun_construct_model(x)
    writesources(output, [sun])
end

function restore_the_sun!(spw, times, data, flags, peeling_data)
    meta = getmeta(spw)
    meta.channels = meta.channels[55:55]
    meta.phase_center = Direction(dir"AZEL", 0degrees, 90degrees)

    N = length(times)
    for integration = 1:N
        my_peeling_data = peeling_data[integration]
        sources = my_peeling_data.sources
        to_peel = my_peeling_data.to_peel
        to_sub  = my_peeling_data.to_sub
        sun_idxs = find(getfield.(sources, 1) .== "Sun")
        if length(sun_idxs) > 0
            sun_idx = sun_idxs[1]
            sun = sources[sun_idx]
            meta.time = Epoch(epoch"UTC", times[integration]*seconds)
            if sun_idx in to_peel # was the Sun peeled?
                calibration = my_peeling_data.calibrations[to_peel .== sun_idx][1]
                restore_the_sun_peeled!(meta, data, sun, calibration, integration)
            elseif sun_idx in to_sub # was the Sun subtracted?
                restore_the_sun_subtracted!(meta, data, sun, integration)
            end
        end
    end
end

function restore_the_sun_peeled!(meta, data, sun, calibration, integration)
    model = genvis(meta, sun)
    corrupt!(model, meta, calibration)
    xx = getfield.(model.data[:, 1], 1)
    yy = getfield.(model.data[:, 1], 4)
    for α = 1:Nbase(meta)
        data[1, α, integration] += xx[α]
        data[2, α, integration] += yy[α]
    end
end

function restore_the_sun_subtracted!(meta, data, sun, integration)
    model = genvis(meta, sun)
    xx = getfield.(model.data[:, 1], 1)
    yy = getfield.(model.data[:, 1], 4)
    for α = 1:Nbase(meta)
        data[1, α, integration] += xx[α]
        data[2, α, integration] += yy[α]
    end
end

function getsun_construct_model(x)
    components = TTCal.Source[]
    push!(components, GaussianSource("Gaussian", Direction(dir"SUN"), PowerLaw(1, 0, 0, 0, 1e6, [0.0]),
                                     deg2rad(1455.88/3600), deg2rad(1976.86/3600), deg2rad(-17.328)))
    push!(components, ShapeletSource("Shapelets", Direction(dir"SUN"), PowerLaw(1, 0, 0, 0, 1e6, [0.0]),
                                     deg2rad((10/60)/sqrt(8log(2))), x))
    MultiSource("Sun", components)
end

function getsun_residual_visibilities(spw, times, data, flags, sun)
    _, Nbase, Ntime = size(data)
    output_data = zeros(Complex128, 2, Nbase)
    output_flags = ones(Bool, Nbase)

    idx = 1
    nextidx() = (myidx = idx; idx += 1; myidx)

    p = Progress(Ntime)
    l = ReentrantLock()
    increment_progress() = (lock(l); next!(p); unlock(l))

    @sync for worker in workers()
        @async while true
            integration = nextidx()
            integration ≤ Ntime || break
            mytime = times[integration]
            mydata = data[:, :, integration]
            myflags = flags[:, integration]
            mydata = remotecall_fetch(getsun_peel_sun_worker, worker,
                                      spw, mytime, mydata, myflags, sun)
            for α = 1:Nbase
                if !myflags[α]
                    output_data[1, α] += mydata[1, α]
                    output_data[2, α] += mydata[2, α]
                    output_flags[α] = false
                end
            end
            increment_progress()
        end
    end

    output_data, output_flags
end

function getsun_peel_sun_worker(spw, time, data, flags, sun)
    meta = getmeta(spw)
    meta.channels = meta.channels[55:55]
    meta.phase_center = Direction(dir"AZEL", 0degrees, 90degrees)
    meta.time = Epoch(epoch"UTC", time*seconds)

    visibilities = Visibilities(Nbase(meta), 1)
    for α = 1:Nbase(meta)
        visibilities.data[α, 1] = JonesMatrix(data[1, α], 0, 0, data[2, α])
        visibilities.flags[α, 1] = flags[α]
    end
    TTCal.flag_short_baselines!(visibilities, meta, 15.0)

    peel!(visibilities, meta, ConstantBeam(), [sun], peeliter=1, maxiter=100, tolerance=1e-3, quiet=true)

    output = zeros(Complex128, 2, Nbase(meta))
    center = PointSource("phase center", Direction(dir"SUN"), PowerLaw(1, 0, 0, 0, 1e6, [0.0]))
    model = genvis(meta, [center])
    for α = 1:Nbase(meta)
        J = visibilities.data[α, 1] / model.data[α, 1]
        output[1, α] = J.xx
        output[2, α] = J.yy
    end
    output
end

function getsun_residual_image(spw, summed_data, summed_flags)
    Nbase = size(summed_data, 2)
    output = Visibilities(Nbase, 109)
    output.flags[:] = true
    output.flags[:, 55] = summed_flags
    for α = 1:Nbase
        output.data[α, 55] = JonesMatrix(summed_data[1, α], 0, 0, summed_data[2, α])
    end

    path = "/dev/shm/mweastwood/getsun-output.ms"
    if !isdir(path)
        dada = listdadas(spw, "rainy")[1]
        dada2ms_core(dada, path, "rainy")
    end
    ms = Table(path)
    TTCal.write(ms, "CORRECTED_DATA", output)
    unlock(ms)
    wsclean(path)

    pixels = getsun_identify_pixels()
    fits = FITS(replace(path, ".ms", ".fits"))
    img = convert(Matrix{Float64}, read(fits[1])[:,:,1,1])
    values = Float64[]
    for (idx, jdx) in pixels
        push!(values, img[idx, jdx])
    end
    std(values)
end

function getsun_identify_pixels()
    center = (1+2048)/2
    pixels = Tuple{Int, Int}[]
    for y = 1:2048, x = 1:2048
        if hypot(x - center, y - center) < 30
            push!(pixels, (x, y))
        end
    end
    pixels
end

