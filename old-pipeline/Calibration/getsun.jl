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
        @show now()
        @show x
        sun = getsun_construct_model(x)
        println("* Peeling the Sun")
        summed_data, summed_flags = getsun_residual_visibilities(spw, times, data, flags, sun)
        println("* Imaging the residuals")
        output = getsun_residual_image(spw, summed_data, summed_flags)
        @show output
        output
    end

    # SHAPELETS

    # spw18
    #x0 = [1455.88, 1976.86, -17.328,
    #      -0.1510759761698713,   -0.02066199368032352,   -0.018493304474277106, -0.0012873111106452735,
    #      -0.036009230301391706,  0.00016816926519434334, 0.10053548515299322,  -0.0012698942453968239,
    #       0.009018968911481295, -0.005032715278400886,   0.06749641456795911,   0.0002023066369522653,
    #       0.0017188608486568857, 0.001160116390556377,  -0.02489101087535827,   0.00010983142769303976]

    # spw14
    #x0 = [1622.2669729386591, 2293.413730331039, -20.0493648229423,
    #      -0.13658950102982556, -0.0015192147751638962, -0.014392339908425792, -0.005765899007730887,
    #      -0.047316905221074665, 0.04824140333473242,    0.10639368298705491,  -0.00761371053942145,
    #       0.02182254648237799, -0.007500232542486043,   0.06014367076653129,   0.0026133957685073057,
    #       0.005094455449773894, 0.0002991638049416478, -0.026020631618510058, -0.0010620435723069604]

    #xmin = [1000, 1000, -90,
    #        -0.5, -0.2, -0.2, -0.2,
    #        -0.2, -0.2, -0.2, -0.2,
    #        -0.2, -0.2, -0.2, -0.2,
    #        -0.2, -0.2, -0.2, -0.2]

    #xmax = [3000, 3000, +90,
    #        +0.5, +0.2, +0.2, +0.2,
    #        +0.2, +0.2, +0.2, +0.2,
    #        +0.2, +0.2, +0.2, +0.2,
    #        +0.2, +0.2, +0.2, +0.2]

    # GRID

    #x0 = [1622.2669729386591, 2293.413730331039, -20.0493648229423,
    #      0, 0, 0, 0, 0,
    #      0, 0, 0, 0, 0,
    #      0, 0, 0, 0, 0,
    #      0, 0, 0, 0, 0,
    #      0, 0, 0, 0, 0]

    #x0 = [1760.76,2325.9,-19.4771,-0.00356445,0.0995863,-0.00841577,0.0797242,0.0280154,0.0276592,0.00507813,-0.00517578,-0.018772,-0.00421448,-0.02995,0.00117188,-0.101367,0.0,0.0557388,-0.0145996,0.149181,0.0177734,-0.0171397,-0.0134434,-0.0159446,0.0,-0.0511719,-0.00947266,0.0621676]
    #x0 = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
    #      0.0, -0.00356445,0.0995863, -0.00841577, 0.0797242, 0.0280154, 0.0,
    #      0.0,  0.0276592, 0.00507813,-0.00517578,-0.018772, -0.00421448, 0.0,
    #      0.0, -0.02995,   0.00117188,-0.101367,   0.0,       0.0557388, 0.0,
    #      0.0, -0.0145996, 0.149181,   0.0177734, -0.0171397,-0.0134434, 0.0,
    #      0.0, -0.0159446, 0.0,       -0.0511719, -0.00947266,0.0621676, 0.0,
    #      0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
    x0 = [-0.0020117187500000014,  0.017705078125000002,   0.008466796875000002,   0.0013037109375000004,  0.001181640625,        0.00154296875,        -0.009316406250000003,
           0.0007861328124999996, -0.0299462859375,        0.09834362421875001,   -0.012478270000000001,   0.05074959062499998,   0.0420046578125,       0.0,
          -0.01505859375,          0.026897481249999994,   0.0025781299999999997, -0.005419920625,        -0.0236401640625,      -0.00442932375,         0.008613281250000002,
           0.0012109375000000002, -0.026370898437500005,  -0.0024951121875,       -0.09193955383300781,    0.006054687500000004,  0.049244659375,        0.016832275390625,
          -0.006777343750000001,  -0.0066699125000000015,  0.13780627851562502,    0.0368407828125,       -0.038292043750000004, -0.0152012125,         -0.004091796875,
          -0.0057519531250000006, -0.0180930375,          -0.012348632812500003,  -0.0511719,             -0.00947266,            0.0627926,            -0.0113671875,
           0.0,                   -0.00103515625,          0.00033203125,         -0.00478515625,          7.812499999999996e-5,  0.006445312500000002,  0.0004589843750000001]

    xmin = [#1000, 1000, -90,
            -0.2, -0.2, -0.2, -0.2, -0.2, -0.2, -0.2,
            -0.2, -0.2, -0.2, -0.2, -0.2, -0.2, -0.2,
            -0.2, -0.2, -0.2, -0.2, -0.2, -0.2, -0.2,
            -0.2, -0.2, -0.2, -0.2, -0.2, -0.2, -0.2,
            -0.2, -0.2, -0.2, -0.2, -0.2, -0.2, -0.2,
            -0.2, -0.2, -0.2, -0.2, -0.2, -0.2, -0.2,
            -0.2, -0.2, -0.2, -0.2, -0.2, -0.2, -0.2]

    xmax = [#3000, 3000, +90,
            +0.2, +0.2, +0.2, +0.2, +0.2, +0.2, +0.2,
            +0.2, +0.2, +0.2, +0.2, +0.2, +0.2, +0.2,
            +0.2, +0.2, +0.2, +0.2, +0.2, +0.2, +0.2,
            +0.2, +0.2, +0.2, +0.2, +0.2, +0.2, +0.2,
            +0.2, +0.2, +0.2, +0.2, +0.2, +0.2, +0.2,
            +0.2, +0.2, +0.2, +0.2, +0.2, +0.2, +0.2,
            +0.2, +0.2, +0.2, +0.2, +0.2, +0.2, +0.2]


    # GAUSSIANS

    #x0   = [ 0,  0, 0.1,   60,   60,   0]
    #xmin = [-3, -3,  -2,    1,    1, -90]
    #xmax = [+3, +3,  +2, 3000, 3000, +90]

    opt = Opt(:LN_SBPLX, length(x0))
    ftol_rel!(opt, 1e-3)
    min_objective!(opt, residual)
    lower_bounds!(opt, xmin)
    upper_bounds!(opt, xmax)
    minf, x, ret = optimize(opt, x0)
    println("++++")
    println("DONE")
    @show minf, x, ret
    #x = x0

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
    #push!(components, GaussianSource("Gaussian", Direction(dir"SUN"), PowerLaw(1, 0, 0, 0, 1e6, [0.0]),
    #                                 deg2rad(x[1]/3600), deg2rad(x[2]/3600), deg2rad(x[3])))
    #push!(components, ShapeletSource("Shapelets", Direction(dir"SUN"), PowerLaw(1, 0, 0, 0, 1e6, [0.0]),
    #                                 deg2rad((10/60)/sqrt(8log(2))), x[4:end]))

    center  = [0.8582255291849628, -0.4709258203615475, -0.20415144567696358]
    center /= norm(center)
    north   = [0, 0, 1] - center[3] * center
    north  /= norm(north)
    east    = cross(north, center)

    #push!(components, GaussianSource("Blob 1",
    #                                 Direction(dir"J2000", center[1], center[2], center[3]),
    #                                 PowerLaw(1, 0, 0, 0, 1e6, [0.0]),
    #                                 deg2rad(1760.76/3600), deg2rad(2325.9/3600), deg2rad(-19.4771)))

    #y = [-2.56964,0.352722,0.0725447,1.0,823.831,-16.5674]
    #_center  = center + 0.002*y[1]*north + 0.002*y[2]*east
    #_center /= norm(_center)
    #push!(components, GaussianSource("Blob New",
    #                                 Direction(dir"J2000", _center[1], _center[2], _center[3]),
    #                                 PowerLaw(y[3], 0, 0, 0, 1e6, [0.0]),
    #                                 deg2rad(y[4]/3600), deg2rad(y[5]/3600), deg2rad(y[6])))

    #_center  = center + 0.002*x[1]*north + 0.002*x[2]*east
    #_center /= norm(_center)
    #push!(components, GaussianSource("Blob New",
    #                                 Direction(dir"J2000", _center[1], _center[2], _center[3]),
    #                                 PowerLaw(x[3], 0, 0, 0, 1e6, [0.0]),
    #                                 deg2rad(x[4]/3600), deg2rad(x[5]/3600), deg2rad(x[6])))

    x0 = [1760.76,2325.9,-19.4771]
    push!(components, GaussianSource("Fuzzy Blob",
                                     Direction(dir"J2000", center[1], center[2], center[3]),
                                     PowerLaw(1, 0, 0, 0, 1e6, [0.0]),
                                     deg2rad(x0[1]/3600), deg2rad(x0[2]/3600), deg2rad(x0[3])))

    count = 1
    for idx = -3:3, jdx = -3:3
        _center  = center + 0.002*idx*north + 0.002*jdx*east
        _center /= norm(_center)
        push!(components, GaussianSource("Pixel ($idx, $jdx)",
                                         Direction(dir"J2000", _center[1], _center[2], _center[3]),
                                         PowerLaw(x[count], 0, 0, 0, 1e6, [0.0]),
                                         deg2rad(10/60), deg2rad(10/60), 0))
        #push!(components, GaussianSource("Pixel ($idx, $jdx)",
        #                                 Direction(dir"J2000", _center[1], _center[2], _center[3]),
        #                                 PowerLaw(x[count], 0, 0, 0, 1e6, [0.0]),
        #                                 deg2rad(5/60), deg2rad(5/60), 0))
        #push!(components, PointSource("Pixel ($idx, $jdx)",
        #                              Direction(dir"J2000", _center[1], _center[2], _center[3]),
        #                              PowerLaw(x[count], 0, 0, 0, 1e6, [0.0])))
        count += 1
    end

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

