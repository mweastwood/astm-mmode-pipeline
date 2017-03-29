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
    @show integrations
    times = times[integrations]
    data = data[:, :, integrations]
    flags = flags[:, integrations]
    peeling_data = peeling_data[integrations]

    # Apply some new flags
    #bad = [44, 45, 89, 92]
    #for ant1 = 1:256, ant2 = ant1:256
    #    if ant1 in bad || ant2 in bad
    #        α = baseline_index(ant1, ant2)
    #        flags[α, :] = true
    #    end
    #end

    # Get the J2000 position of the Sun.
    # We need to do this because CasaCore seems to discard the longitude and latitude information
    # when the coordinate system is dir"SUN". That is, we need to convert to J2000 coordinates if we
    # want to have any hope of adding components that are not centered on the Sun.
    meta = getmeta(spw)
    meta.time = Epoch(epoch"UTC", times[1]*seconds)
    meta.channels = meta.channels[55:55]
    frame = TTCal.reference_frame(meta)
    j2000_sun = measure(frame, Direction(dir"SUN"), dir"J2000")

    Lumberjack.info("* Restoring the Sun")
    restore_the_sun!(spw, times, data, flags, peeling_data)

    function residual(x, g)
        println("=====")
        @show x
        sun = getsun_construct_model(x, j2000_sun)
        @show sun
        Lumberjack.info("* Peeling the Sun")
        summed_data, summed_flags = getsun_residual_visibilities(spw, times, data, flags, sun)
        Lumberjack.info("* Imaging the residuals")
        output = getsun_residual_image(spw, summed_data, summed_flags)
        @show output
        output
    end

    ## first component
    #x0 = [1455.88,1976.86,-17.328]
    #xmin = [ 900,  900, -90]
    #xmax = [2700, 2700, +90]

    ## second component
    #x0   = [1080, 2160,     0,     0, -1e-1,   0]
    #xmin = [  10,   10, -1800, -1800, -1e+0, -90]
    #xmax = [2700, 2700, +1800, +1800, +1e+0, +90]

    #x0   = [+1e-1,  900, 1456, 1976,   0]
    #x0 = [0.115625,1141.41,1456.0,1976.0,0.0]
    #xmin = [-1e+0,  600,   10,   10, -90]
    #xmax = [+1e+0, 1200, 2700, 2700, +90]

    #nmax = 4
    #β = deg2rad((27.25/60)/sqrt(8log(2)))
    #test = fit_shapelets("Sun", meta, data[1,:,1], data[2,:,1], flags[:,1],
    #                     Direction(dir"SUN"), nmax, β)

    #x0 = test.coeff
    #x0 /= x0[1]
    #x0 = x0[2:end]
    #N = length(x0)
    #xmin = -2ones(N)
    #xmax = +2ones(N)

    N = 3^2
    #x0 = zeros(N)
    #x0 = [-0.0753959,-0.00145539,0.00266602,0.0242334,-0.1,-0.1,0.0295977,-0.0173477,0.00625]
    x0 = [-0.13409285774780416,
          -0.004796965460003634,
          -0.019117673589174062,
          -0.023768901318089203,
          -0.009905264231943971,
          0.0011628254753725253,
          0.0026279465322257595,
          -0.015391347830533647,
          0.06347919129885458]
    xmin = -ones(N)
    xmax = +ones(N)

    #residual(x0, [])

    opt = Opt(:LN_SBPLX, length(x0))
    min_objective!(opt, residual)
    ftol_rel!(opt, 1e-3)
    lower_bounds!(opt, xmin)
    upper_bounds!(opt, xmax)
    minf, x, ret = optimize(opt, x0)

    println("++++")
    println("DONE")
    @show minf, x, ret

    for y in x
       println(y)
    end
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
        else
            @show integration
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

function getsun_construct_model(x, j2000_sun)
    ra = longitude(j2000_sun)
    dec = latitude(j2000_sun)
    components = TTCal.Source[]
    #push!(components, DiskSource("disk", Direction(dir"J2000", ra*radians, dec*radians),
    #                             PowerLaw(x[1], 0, 0, 0, 1e6, [0.0]), deg2rad(x[2]/3600)))
    ##push!(components, GaussianSource("1",
    ##                                 Direction(dir"J2000", ra*radians, dec*radians),
    ##                                 PowerLaw(1.0, 0, 0, 0, 1e6, [0.0]),
    ##                                 deg2rad(x[1]), deg2rad(x[2]), x[3]))
    #push!(components, GaussianSource("1",
    #                                 Direction(dir"J2000", ra*radians, dec*radians),
    #                                 PowerLaw(1, 0, 0, 0, 1e6, [0.0]),
    #                                 deg2rad(1582.8055000305176/3600),
    #                                 deg2rad(1641.3765989031112/3600),
    #                                 deg2rad(-10.79695783342634)))
    push!(components, GaussianSource("1",
                                     Direction(dir"SUN"),
                                     PowerLaw(1, 0, 0, 0, 1e6, [0.0]),
                                     deg2rad(1455.88/3600),
                                     deg2rad(1976.86/3600),
                                     deg2rad(-17.328)))
    ##push!(components, DiskSource("disk", Direction(dir"J2000",
    ##                                               (ra+deg2rad(x[1]/3600))*radians,
    ##                                               (dec+deg2rad(x[2]/3600))*radians),
    ##                             PowerLaw(x[4], 0, 0, 0, 1e6, [0.0]), deg2rad(x[3]/3600)))
    #push!(components, GaussianSource("2",
    #                                 Direction(dir"J2000", ra*radians, dec*radians),
    #                                 PowerLaw(1, 0, 0, 0, 1e6, [0.0]),
    #                                 deg2rad(x[3]/3600), deg2rad(x[4]/3600), deg2rad(x[5])))
    push!(components, ShapeletSource("Sun", Direction(dir"SUN"), PowerLaw(1, 0, 0, 0, 1e6, [0.0]),
                                     deg2rad((10/60)/sqrt(8log(2))), x))
    MultiSource("Sun", components)
    #ShapeletSource("Sun", Direction(dir"SUN"), PowerLaw(1, 0, 0, 0, 1e6, [0.0]),
    #               deg2rad((x[1]/60)/sqrt(8log(2))), [1; x[2:end]])
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

