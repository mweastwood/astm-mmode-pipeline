function getcas()
    Lumberjack.info("Fitting a model of Cas A")
    spw = 18
    #integrations = 16200:16500
    #integrations = 16200:16300
    integrations = 3315:4971
    sources = readsources(joinpath(sourcelists, "getdata-sources.json"))[1:2]
    #getcyg_prepare_measurement_sets(spw, integrations, sources, "Cas A")
    #create_template_ms(spw, joinpath(getdir(spw), "tmp", "getcyg-output.ms"))

    function residual(x, g)
        source = getcas_construct_model(x)
        output = getcyg_residual(spw, integrations, source)
        @show x, output
        output
    end

    #x0 = [rad2deg(sexagesimal("23h23m12.78s")), rad2deg(sexagesimal("+58d50m41.0s")),
    #x0 = [rad2deg(sexagesimal("23h23m28.09s")), rad2deg(sexagesimal("+58d49m18.1s")),
    #      268333.87, 208.9/3600, 84.1/3600, 38.9, 230.9/3600, 121.9/3600, 43.8]
    #x0 = [351.003,58.7629,350.951,59.0217,100.0,0.0565895,0.0390652,49.5159,0.000277778,0.000277778,21.4816]
    #xmin = [x0[1]-0.2, x0[2]-0.2, x0[3]-0.2, x0[4]-0.2, 1e2, 1/3600, 1/3600, -90, 1/3600, 1/3600, -90]
    #xmax = [x0[1]+0.2, x0[2]+0.2, x0[3]+0.2, x0[4]+0.2, 1e8, 1, 1, +90, 1, 1, +90]
    #x0 = [350.867,58.8217,3.15058e5,0.0755604,0.0233611,38.9,0.0641389,0.0338611,43.8]
    #xmin = [x0[1]-0.2, x0[2]-0.2, 1e2, 1/3600, 1/3600, -90, 1/3600, 1/3600, -90]
    #xmax = [x0[1]+0.2, x0[2]+0.2, 1e8, 1, 1, +90, 1, 1, +90]
    #permutation = [4,5,7,8,6,9,3,1,2]
    #x0 = x0[permutation]
    #xmin = xmin[permutation]
    #xmax = xmax[permutation]
    
    # This one is the best so far
    #x0 = [350.817,58.8682,71553.0,203.389,135.225,90.0]
    #x0 = [350.837,58.8472,1.37297e5,159.768,113.96,90.0]
    x0 = [350.837,58.8472,2.22803e5,173.26,63.4649,121.902]
    #x0 = [rad2deg(sexagesimal("23h23m24s")), rad2deg(sexagesimal("58d48m54s")), 1e5, 60, 60, 0]
    xmin = [x0[1]-0.2, x0[2]-0.2, 1, 1, 1, 0]
    xmax = [x0[1]+0.2, x0[2]+0.2, 1e8, 3600, 3600, 180]

    #x0 = [rad2deg(sexagesimal("23h23m28.09s")), rad2deg(sexagesimal("+58d49m18.1s")),
    #      268333.87, 208.9/3600, 84.1/3600, 38.9, 230.9/3600, 121.9/3600, 43.8]

    #nmax = 2
    #x0 = [deg2rad(0.05); zeros((nmax+1)^2-1)]

    ###x0 = [0.0565895,0.0390652,49.5159]
    ##x0 = [0.0554138,0.0150277,35.57]
    #x0 = [0.166667,0.165062,35.57]
    #xmin = [1/3600, 1/3600, -90]
    #xmax = [30/60, 30/60, +90]

    #opt = Opt(:LN_SBPLX, length(x0))
    ##opt = Opt(:LN_PRAXIS, length(x0))
    #min_objective!(opt, residual)
    #ftol_rel!(opt, 1e-3)
    #lower_bounds!(opt, xmin)
    #upper_bounds!(opt, xmax)
    #minf, x, ret = optimize(opt, x0)
    #@show minf x ret
    #for y in x
    #    println(y)
    #end
    x = x0

    @show getcyg_residual(spw, integrations, getcas_construct_model(x))

    output = joinpath(sourcelists, "cas-$(now()).json")
    cas = getcas_construct_model(x)

    # Fix Cas's spectrum
    desired_spectrum = PowerLaw(555904.26, 0, 0, 0, 1e6, [-0.770])
    component_fluxes = [component.spectrum.stokes.I for component in cas.components]
    total_flux = sum(component_fluxes)
    component_fluxes *= desired_spectrum.stokes.I / total_flux
    for (flux, component) in zip(component_fluxes, cas.components)
        component_spectrum = deepcopy(desired_spectrum)
        component_spectrum.stokes = StokesVector(flux, 0, 0, 0)
        component.spectrum = component_spectrum
    end

    writesources(output, [cas])
end

function getcas_construct_model(x)
    components = TTCal.Source[]
    push!(components, GaussianSource("1",
                                     Direction(dir"J2000", "23h23m12.78s", "+58d50m41.0s"),
                                     PowerLaw(287570.39, 0, 0, 0, 1e6, [-0.770]),
                                     deg2rad(208.9/3600), deg2rad(84.1/3600), deg2rad(38.9)))
    push!(components, GaussianSource("2",
                                     Direction(dir"J2000", "23h23m28.09s", "+58d49m18.1s"),
                                     PowerLaw(268333.87, 0, 0, 0, 1e6, [-0.770]),
                                     deg2rad(230.9/3600), deg2rad(121.9/3600), deg2rad(43.8)))
    push!(components, GaussianSource("3",
                                     Direction(dir"J2000", x[1]*degrees, x[2]*degrees),
                                     PowerLaw(x[3], 0, 0, 0, 1e6, [-0.770]),
                                     deg2rad(x[4]/3600), deg2rad(x[5]/3600), deg2rad(x[6])))
    MultiSource("Cas A", components)
    #ShapeletSource("Cas A", Direction(dir"J2000", "23h23m24s", "+58d48m54s"),
    #               PowerLaw(1, 0, 0, 0, 47e6, [-0.770]),
    #               x[1], [1; x[2:end]])
    #GaussianSource("Cas A", Direction(dir"J2000", "23h23m24s", "+58d48m54s"),
    #               PowerLaw(1, 0, 0, 0, 47e6, [-0.770]),
    #               deg2rad(x[1]), deg2rad(x[2]), deg2rad(x[3]))
end

"""
    getcyg_prepare_measurement_sets(spws, integrations, sources, keep)

Prepare a list of measurement sets for use in fitting a model of Cyg A.

* `spw` - the spectral window
* `integrations` - the list of integrations to use
* `sources` - the list of sources to peel from the measurement sets
* `keep` - the name of the source that will be restored
"""
function getcyg_prepare_measurement_sets(spw, integrations, sources, keep)
    dadas = listdadas(spw)
    calinfo = readcals(spw)

    idx = 1
    N = length(integrations)
    nextidx() = (myidx = idx; idx += 1; myidx)
    idx2params(idx) = integrations[idx]

    p = Progress(N, "Progress: ")
    l = ReentrantLock()
    increment_progress() = (lock(l); next!(p); unlock(l))

    Lumberjack.info("Preparing the measurement sets")
    @sync for worker in workers()
        @async while true
            myidx = nextidx()
            myidx ≤ N || break
            integration = idx2params(myidx)
            Lumberjack.debug("Worker $worker is processing spw $spw integration $integration")
            remotecall_fetch(getcyg_prepare_measurement_set, worker,
                             spw, dadas[integration], sources, calinfo, keep)
            increment_progress()
        end
    end
end

function getcyg_prepare_measurement_set(spw, file, sources, calinfo, keep)
    ms, path = dada2ms(file)
    caltimes, cal = calinfo

    flag!(ms, spw)
    data = TTCal.read(ms, "DATA")
    meta = Metadata(ms)
    beam = ConstantBeam()
    frame = TTCal.reference_frame(meta)

    # - find the nearest calibration in time and apply it
    time = ms["TIME", 1]
    idx = indmin(abs2(caltimes-time))
    applycal!(data, meta, cal[idx])

    # - flag short baselines
    oldflags = copy(data.flags)
    minuvw = 15.0
    TTCal.flag_short_baselines!(data, meta, minuvw)

    # - begin by classifying the sources based on how we intend to remove them
    sources = TTCal.abovehorizon(frame, sources)
    sources, spectra, directions = update_source_list(data, meta, sources)

    # - pare down the dataset to just the channel of interest
    β = 55
    ν = meta.channels[β]
    range = β:β
    meta.channels = meta.channels[range]
    data.data  = data.data[:, range]
    data.flags = data.flags[:, range]

    # - decide how we are going to remove each source
    A, B = pick_removal_method(spw, frame, sources, ν)
    rfi = pick_rfi_sources(spw, data, meta)
    sun = get_the_sun(spw, data, meta)
    A = [A; rfi; sun]

    # - do the source removal
    calibrations = peel!(data, meta, beam, A, peeliter=5, maxiter=30, tolerance=1e-3, quiet=true)
    B, _, _ = update_source_list(data, meta, B)
    subsrc!(data, meta, beam, B)

    # - restore a source to the measurement set
    idx = find(source.name == keep for source in A)
    if length(idx) > 0
        coherency = genvis(meta, beam, A[idx])
        corrupt!(coherency, meta, calibrations[idx][1])
        data.data += coherency.data
    end

    output = joinpath(getdir(spw), "tmp", "getcyg-"*replace(basename(file), ".dada", ".jld"))
    save(output, "meta", meta, "data", data)
    finalize(ms)
    rm(path, recursive=true)
end

"""
    getcyg_residual(spws, integrations, source)

Compute a measure of the residual after peeling the given source model.

* `spw` - the spectral window
* `integrations` - the list of integrations to use
* `source` - the source model
"""
function getcyg_residual(spw, integrations, source)
    dadas = listdadas(spw)

    idx = 1
    N = length(integrations)
    nextidx() = (myidx = idx; idx += 1; myidx)
    idx2params(idx) = integrations[idx]

    p = Progress(N, "Progress: ")
    l = ReentrantLock()
    increment_progress() = (lock(l); next!(p); unlock(l))

    meta = getmeta(spw)
    data = Visibilities(Nbase(meta), 1)
    add_to_data(mydata) = data.data += mydata.data
    set_flags(mydata) = data.flags = mydata.flags

    integration_flags = load(joinpath(getdir(spw), "integration-flags.jld"), "flags")

    Lumberjack.info("Measuring residuals after peeling")
    @sync for worker in workers()
        @async while true
            myidx = nextidx()
            myidx ≤ N || break
            integration = idx2params(myidx)
            if !integration_flags[integration]
                file = dadas[integration]
                path = joinpath(getdir(spw), "tmp", "getcyg-"*replace(basename(file), ".dada", ".jld"))
                mydata = remotecall_fetch(getcyg_residual, worker, path, source)
                add_to_data(mydata)
                myidx == 1 && set_flags(mydata)
            end
            increment_progress()
        end
    end

    output = Visibilities(Nbase(meta), 109)
    output.flags[:] = true
    output.data[:, 55] = data.data
    output.flags[:, 55] = data.flags

    if !isdir("/dev/shm/mweastwood/getcyg-output.ms")
        cp(joinpath(getdir(spw), "tmp", "getcyg-output.ms"), "/dev/shm/mweastwood/getcyg-output.ms")
    end
    ms = Table("/dev/shm/mweastwood/getcyg-output.ms")
    TTCal.write(ms, "CORRECTED_DATA", output)
    unlock(ms)
    finalize(ms)

    wsclean("/dev/shm/mweastwood/getcyg-output.ms")

    # measure the variance of the Cyg A residual
    pixels = identify_pixels()
    fits = FITS("/dev/shm/mweastwood/getcyg-output.fits")
    img = convert(Matrix{Float64}, read(fits[1])[:,:,1,1])
    values = Float64[]
    pixels = identify_pixels()
    for (idx, jdx) in pixels
        push!(values, img[idx, jdx])
    end
    var(values / N)
end

function getcyg_residual(path, source)
    data, meta = retry(load; n=3)(path, "data", "meta")
    beam = ConstantBeam()
    peel!(data, meta, beam, [source], peeliter=1, maxiter=100, tolerance=1e-5, quiet=true)

    # Make sure to change this when doing Cyg instead
    center = PointSource("Cas A", Direction(dir"J2000", "23h23m24s", "+58d48m54s"),
                         PowerLaw(1, 0, 0, 0, 1e6, [0.0]))
    model = genvis(meta, [center])
    for idx in eachindex(data.data, model.data)
        data.data[idx] = data.data[idx] / model.data[idx]
    end
    data
end

#function getcyg()
#    Lumberjack.info("Fitting a model of Cygnus A")
#    #spws = [4, 12, 18]
#    spws = [4]
#    #range = 23580:24080
#    range = 23580:23680
#    workload = distribute_workload(spws, range)
#    prepare_ms(spws, range, workload)
#    cyg = readsources(joinpath(sourcelists, "detailed-sources.json"))[1]
#    #cyg = readsources(joinpath(sourcelists, "cyg-2016-07-30T10:52:45.json"))[1]
#    #cyg = readsources(joinpath(sourcelists, "cyg-2016-08-04T21:27:45.json"))[1]
#    getcyg_residual(spws, range, workload, cyg, move=true)
#
#    #=
#    function residual(x, g)
#        println("===")
#        @show x
#        mycyg = construct_model(x)
#        output = getcyg_residual(spws, range, workload, mycyg)
#        @show output
#        output
#    end
#
#    cyg = readsources(joinpath(sourcelists, "detailed-sources.json"))[1]
#    east = cyg.components[1]
#    west = cyg.components[2]
#
#    x = [rad2deg(longitude(east.direction)), rad2deg(latitude(east.direction)),
#         rad2deg(longitude(west.direction)), rad2deg(latitude(west.direction)),
#         west.spectrum.stokes.I,
#         1/60, 1/60, 0,
#         1/60, 1/60, 0]
#    xmin = [x[1]-0.2, x[2]-0.2, x[3]-0.2, x[4]-0.2, 1e0, 1/3600, 1/3600, -90, 1/3600, 1/3600, -90]
#    xmax = [x[1]+0.2, x[2]+0.2, x[3]+0.2, x[4]+0.2, 1e6, 10/60, 10/60, +90, 10/60, 10/60, +90]
#
#    opt = Opt(:LN_SBPLX, 11)
#    min_objective!(opt, residual)
#    ftol_rel!(opt, 1e-5)
#    lower_bounds!(opt, xmin)
#    upper_bounds!(opt, xmax)
#    minf, x, ret = optimize(opt, x)
#    @show minf x ret
#    residual(x, [])
#
#    output = joinpath(sourcelists, "cyg-$(now()).json")
#    cyg = construct_model(x)
#
#    # Fix Cyg's spectrum
#    desired_spectrum = PowerLaw(49545.02, 0, 0, 0, 1e6, [+0.085, -0.178])
#    component_fluxes = [component.spectrum.stokes.I for component in cyg.components]
#    total_flux = sum(component_fluxes)
#    component_fluxes *= desired_spectrum.stokes.I / total_flux
#    for (flux, component) in zip(component_fluxes, cyg.components)
#        component_spectrum = deepcopy(desired_spectrum)
#        component_spectrum.stokes = StokesVector(flux, 0, 0, 0)
#        component.spectrum = component_spectrum
#    end
#
#    writesources(output, [cyg])
#    =#
#
#    nothing
#end
#
#function construct_model(x)
#    components = TTCal.Source[]
##    push!(components, GaussianSource("east",
##                                     Direction(dir"J2000", "19h59m29.99s", "+40d43m57.53s"),
##                                     PowerLaw(29523.00, 0, 0, 0, 1e6, [0.085, -0.178]),
##                                     deg2rad(x[1]), deg2rad(x[2]), deg2rad(x[7])))
##    push!(components, GaussianSource("west",
##                                     Direction(dir"J2000", x[5]*degrees, x[6]*degrees),
##                                     PowerLaw(x[9], 0, 0, 0, 1e6, [0.085, -0.178]),
##                                     deg2rad(x[3]), deg2rad(x[4]), deg2rad(x[8])))
#    push!(components, GaussianSource("east",
#                                     Direction(dir"J2000", x[1]*degrees, x[2]*degrees),
#                                     PowerLaw(29523.00, 0, 0, 0, 1e6, [0.085, -0.178]),
#                                     deg2rad(x[6]), deg2rad(x[7]), deg2rad(x[8])))
#    push!(components, GaussianSource("west",
#                                     Direction(dir"J2000", x[3]*degrees, x[4]*degrees),
#                                     PowerLaw(x[5], 0, 0, 0, 1e6, [0.085, -0.178]),
#                                     deg2rad(x[9]), deg2rad(x[10]), deg2rad(x[11])))
#    MultiSource("Cyg A", components)
#end
#
#function distribute_workload(spws, range)
#    N = length(spws)*length(range)
#    idx2params(idx) = (spws[fld(idx-1, length(range)) + 1],
#                       range[((idx - 1) % length(range)) + 1])
#    workload = Dict{Int, Vector{Tuple{Int, Int}}}()
#    for worker in workers()
#        workload[worker] = Tuple{Int, Int}[]
#    end
#    for (idx, worker) in zip(1:N, cycle(workers()))
#        spw, integration = idx2params(idx)
#        push!(workload[worker], (spw, integration))
#    end
#    workload
#end
#
#function prepare_ms(spws, range, workload)
#    sources = readsources(joinpath(sourcelists, "cyg-cas.json"))
#    dadas = Dict{Int, Vector{UTF8String}}()
#    calibrations = Dict{Int, GainCalibration}()
#    Lumberjack.info("Loading calibrations")
#    for spw in spws
#        dadas[spw] = listdadas(spw)
#        _, mycalibrations = readcals(spw)
#        calibrations[spw] = mycalibrations[4]
#    end
#
#    N = length(spws)*length(range)
#    p = Progress(N, "Progress: ")
#    l = ReentrantLock()
#    increment_progress() = (lock(l); next!(p); unlock(l))
#
#    Lumberjack.info("Preparing the measurement sets")
#    @sync for worker in workers()
#        @async begin
#            myworkload = workload[worker]
#            for (spw, integration) in myworkload
#                Lumberjack.debug("Worker $worker is processing integration $integration from spectral window $spw")
#                dada = dadas[spw][integration]
#                calibration = calibrations[spw]
#                remotecall_fetch(worker, prepare_ms, spw, integration, dada, calibration, sources)
#                increment_progress()
#            end
#        end
#    end
#end
#
#function prepare_ms(spw, idx, dada, calibration, sources)
#    ms, path = dada2ms(spw, dada)
#
#    flag!(ms)
#    data = get_data(ms)
#    meta = collect_metadata(ms, Memo178Beam())
#    flag_short_baselines!(data, meta, 15.0)
#    applycal!(data, meta, calibration)
#
#    gains = shave!(data, meta, sources, peeliter=3, maxiter=30, tolerance=1e-3, quiet=true)
#    model = genvis(meta, sources[1])
#    corrupt!(model, meta, gains[1])
#    data.data += model.data
#
#    set_corrected_data!(ms, data, true)
#    TTCal.set_flags!(ms, data)
#    ms["BACKUP_DATA"] = ms["CORRECTED_DATA"]
#
#    name = @sprintf("%02d-%05d", spw, idx)
#    output = joinpath(tempdir, name)
#    output_ms = output*".ms"
#
#    finalize(ms)
#    cp(path, output_ms, remove_destination=true)
#    rm(path, recursive=true)
#    wsclean(output)
#    ascii(output_ms)
#end
#
#function getcyg_residual(spws, range, workload, cyg; move=false)
#    idx = 1
#    N = length(spws)*length(range)
#    nextidx() = (myidx = idx; idx += 1; myidx)
#    idx2params(myidx) = (spws[fld(myidx-1, length(range)) + 1],
#                         range[((myidx - 1) % length(range)) + 1])
#
#    p = Progress(N, "Progress: ")
#    l = ReentrantLock()
#    increment_progress() = (lock(l); next!(p); unlock(l))
#
#    pixels = identify_pixels()
#    values = zeros(length(pixels))
#    add_to_values(myvalues) = values += myvalues
#    #index = 1
#    #output = zeros(length(pixels), N)
#    #add_to_output(myvalues) = (output[:,index] = myvalues; index += 1)
#
#    Lumberjack.info("Measuring residuals after peeling")
#    @sync for worker in workers()
#        @async begin
#            myworkload = workload[worker]
#            for (spw, integration) in myworkload
#                Lumberjack.debug("Worker $worker is processing integration $integration from spectral window $spw")
#                path = joinpath(tempdir, @sprintf("%02d-%05d.ms", spw, integration))
#                myvalues = remotecall_fetch(worker, getcyg_residual, path, cyg, move)
#                add_to_values(myvalues)
#                #add_to_output(myvalues)
#                increment_progress()
#            end
#        end
#    end
#    #output
#    var(values / N)
#end
#
#function getcyg_residual(path, cyg, move)
#    ms = Table(ascii(path))
#    t1 = @elapsed ms["CORRECTED_DATA"] = ms["BACKUP_DATA"]
#    t2 = @elapsed data = TTCal.get_corrected_data(ms)
#    meta = collect_metadata(ms, ConstantBeam())
#
#    # remove the current model for Cyg A from the data
#    t3 = @elapsed gains = shave!(data, meta, [cyg], peeliter=1, maxiter=100, tolerance=1e-5, quiet=true)
#    #t3 = @elapsed gains = peel!(data, meta, [cyg], peeliter=1, maxiter=100, tolerance=1e-5, quiet=true)
#
#    # rotate Cyg A to the phase center
#    center = PointSource("Cyg A", Direction(dir"J2000", "19h59m28.35663s", "+40d44m02.0970s"), PowerLaw(1, 0, 0, 0, 1e6, [0.0]))
#    t4 = @elapsed model = genvis(meta, [center])
#    t5 = @elapsed for idx in eachindex(data.data, model.data)
#        data.data[idx] = data.data[idx] / model.data[idx]
#    end
#
#    # write the data to the measurement set and image
#    t6 = @elapsed set_corrected_data!(ms, data, true)
#    finalize(ms)
#    t7 = @elapsed wsclean(path)
#
#    # measure the variance of the Cyg A residual
#    fits = FITS(replace(path, ".ms", ".fits"))
#    img = convert(Matrix{Float64}, read(fits[1])[:,:,1,1])
#    values = Float64[]
#    pixels = identify_pixels()
#    for (idx, jdx) in pixels
#        push!(values, img[idx, jdx])
#    end
#    #t1, t2, t3, t4, t5, t6, t7
#
#    if move
#        output = joinpath(workspace, "tmp", basename(path))
#        mv(path, output, remove_destination=true)
#    end
#
#    values
#end

"""
    identify_pixels()

Return the list of pixels to look at while measuring the residuals.

Note that we are rotating the phase center to the source so that all the pixels are in the center
of the image.
"""
function identify_pixels()
    center = (1+2048)/2
    pixels = Tuple{Int, Int}[]
    for y = 1:2048, x = 1:2048
        if hypot(x - center, y - center) < 15
            push!(pixels, (x, y))
        end
    end
    pixels
end

