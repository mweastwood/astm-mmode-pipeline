function getsun(spw)
    dir = getdir(spw)
    println("* Loading")
    @time times, data, flags = load(joinpath(dir, "peeled-rainy-visibilities.jld"), "times", "data", "flags")
    @time sun_data = load(joinpath(dir, "sun-peeled-rainy-visibilities.jld"), "data")
    println("* Restoring the Sun")
    getsun(spw, times, data+sun_data, flags)
end

function getsun(spw, times, data, flags)
    integrations = 1850:2750
    times = times[integrations]
    data = data[:, :, integrations]
    flags = flags[:, integrations]

    function residual(x, g)
        println("=====")
        @show x
        sun = getsun_construct_model(x)
        println("* Peeling the Sun")
        summed_data, summed_flags = getsun_residual_visibilities(spw, times, data, flags, sun)
        println("* Imaging the residuals")
        output = getsun_residual_image(spw, summed_data, summed_flags)
        @show output
        output
    end

    # spw18
    #x0 = [1455.88, 1976.86, -17.328,
    #      -0.1510759761698713,   -0.02066199368032352,   -0.018493304474277106, -0.0012873111106452735,
    #      -0.036009230301391706,  0.00016816926519434334, 0.10053548515299322,  -0.0012698942453968239,
    #       0.009018968911481295, -0.005032715278400886,   0.06749641456795911,   0.0002023066369522653,
    #       0.0017188608486568857, 0.001160116390556377,  -0.02489101087535827,   0.00010983142769303976]

    # spw14
    x0 = [1622.2669729386591, 2293.413730331039, -20.0493648229423,
          -0.13658950102982556, -0.0015192147751638962, -0.014392339908425792, -0.005765899007730887,
          -0.047316905221074665, 0.04824140333473242,    0.10639368298705491,  -0.00761371053942145,
           0.02182254648237799, -0.007500232542486043,   0.06014367076653129,   0.0026133957685073057,
           0.005094455449773894, 0.0002991638049416478, -0.026020631618510058, -0.0010620435723069604]


    xmin = [1000, 1000, -90,
            -0.5, -0.2, -0.2, -0.2,
            -0.2, -0.2, -0.2, -0.2,
            -0.2, -0.2, -0.2, -0.2,
            -0.2, -0.2, -0.2, -0.2]

    xmax = [3000, 3000, +90,
            +0.5, +0.2, +0.2, +0.2,
            +0.2, +0.2, +0.2, +0.2,
            +0.2, +0.2, +0.2, +0.2,
            +0.2, +0.2, +0.2, +0.2]

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

    str = @sprintf("spw%02d", spw)
    output = "sun-$str-$(now()).json"
    path = joinpath(dirname(@__FILE__), "..", "..", "workspace", "source-lists", output)
    sun = getsun_construct_model(x)
    writesources(path, [sun])
end

function getsun_construct_model(x)
    components = TTCal.Source[]
    push!(components, GaussianSource("Gaussian", Direction(dir"SUN"), PowerLaw(1, 0, 0, 0, 1e6, [0.0]),
                                     deg2rad(x[1]/3600), deg2rad(x[2]/3600), deg2rad(x[3])))
    push!(components, ShapeletSource("Shapelets", Direction(dir"SUN"), PowerLaw(1, 0, 0, 0, 1e6, [0.0]),
                                     deg2rad((10/60)/sqrt(8log(2))), x[4:end]))
    #push!(components, GaussianSource("Gaussian", Direction(dir"SUN"), PowerLaw(1, 0, 0, 0, 1e6, [0.0]),
    #                                 deg2rad(1455.88/3600), deg2rad(1976.86/3600), deg2rad(-17.328)))
    #push!(components, ShapeletSource("Shapelets", Direction(dir"SUN"), PowerLaw(1, 0, 0, 0, 1e6, [0.0]),
    #                                 deg2rad((10/60)/sqrt(8log(2))), x))
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
    meta = getmeta(spw, "rainy")
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
        Utility.dada2ms_core(dada, path, "rainy")
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

