function getrfi()
    spw = 18
    integrations = 3315:4971
    #integrations = 3315:3315
    sources = readsources(joinpath(sourcelists, "getdata-sources.json"))[1:2]
    #getrfi_prepare_measurement_sets(spw, integrations, sources)
    #create_template_ms(spw, joinpath(getdir(spw), "tmp", "getrfi-output.ms"))
    getrfi_residual(spw, integrations)
end

function getrfi_residual(spw, integrations)
    dadas = listdadas(spw)

    idx = 1
    N = length(integrations)
    nextidx() = (myidx = idx; idx += 1; myidx)
    idx2params(idx) = integrations[idx]

    p = Progress(N, "Progress: ")
    l = ReentrantLock()
    increment_progress() = (lock(l); next!(p); unlock(l))

    meta = getmeta(spw)
    meta.channels = meta.channels[55:55]
    #xx = zeros(Complex128, Nant(meta), N)
    #yy = zeros(Complex128, Nant(meta), N)
    #function save_cal(cal, idx)
    #    for ant = 1:Nant(meta)
    #        xx[ant, idx] = cal.jones[ant, 1].xx
    #        yy[ant, idx] = cal.jones[ant, 1].yy
    #    end
    #end
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
                path = joinpath(getdir(spw), "tmp", "getrfi-"*replace(basename(file), ".dada", ".jld"))
                #mycal = remotecall_fetch(_getrfi_residual, worker, path)
                #save_cal(mycal, myidx)
                #if myidx == 750
                #    mydata = remotecall_fetch(_getrfi_residual, worker, spw, path)
                #    add_to_data(mydata)
                #    set_flags(mydata)
                #end
                mydata = remotecall_fetch(_getrfi_residual, worker, spw, path)
                add_to_data(mydata)
                myidx == 1 && set_flags(mydata)
            end
            increment_progress()
        end
    end
    save("/dev/shm/mweastwood/getrfi-data.jld", "data", data)
    #data = load("/dev/shm/mweastwood/getrfi-data.jld", "data")

    #positions = [Position(pos"WGS84",
    #                      1226.7091391887516meters,
    #                      -118.3147833410907degrees,
    #                      37.145402389570144degrees),
    #             Position(pos"WGS84",
    #                      1214.248326037079meters,
    #                      -118.3852914162684degrees,
    #                      37.3078474772316degrees),
    #             Position(pos"WGS84",
    #                      1232.6294581335637meters,
    #                      -118.36229648059934degrees,
    #                      37.24861167954518degrees),
    #             Position(pos"WGS84",
    #                      1608.21583019197meters,
    #                      -118.23417138204732degrees,
    #                      37.06249388547446degrees)]

    #sources = TTCal.Source[]
    #for idx in (3, 2, 2)
    #    position = positions[idx]
    #    spectrum = RFISpectrum(meta.channels, fill(StokesVector(1, 0, 0, 0), length(meta.channels)))
    #    source = RFISource("RFI $('A' + (idx-1))", position, spectrum)
    #    source.spectrum = RFISpectrum(meta.channels, StokesVector.(getspec(data, meta, source)))
    #    push!(sources, source)
    #end
    #calibrations = peel!(data, meta, ConstantBeam(), sources, peeliter=5, maxiter=100, tolerance=1e-5, quiet=true)

    #for (idx, source) in enumerate(sources)
    #    @show idx
    #    model = genvis(meta, ConstantBeam(), source)
    #    corrupt!(model, meta, calibrations[idx])
    #    str = @sprintf("spw%02d", spw)
    #    save(joinpath(getdir(spw), "rfi-$idx.jld"), "model", model)
    #end

    output = Visibilities(Nbase(meta), 109)
    output.flags[:] = true
    output.data[:, 55] = data.data
    output.flags[:, 55] = data.flags

    if !isdir("/dev/shm/mweastwood/getrfi-output.ms")
        cp(joinpath(getdir(spw), "tmp", "getrfi-output.ms"), "/dev/shm/mweastwood/getrfi-output.ms")
    end
    ms = Table("/dev/shm/mweastwood/getrfi-output.ms")
    TTCal.write(ms, "CORRECTED_DATA", output)
    unlock(ms)
    finalize(ms)

    wsclean("/dev/shm/mweastwood/getrfi-output.ms")
    ##mv("/dev/shm/mweastwood/getrfi-output.fits", "/dev/shm/mweastwood/getrfi-image.fits", remove_destination=true)

    #for idx = 2:2#(idx, source) in enumerate(sources)
    #    @show idx
    #    ms = Table("/dev/shm/mweastwood/getrfi-output.ms")
    #    model = load(joinpath(getdir(spw), "rfi-$idx.jld"), "model")
    #    output.data[:, 55] = model.data
    #    TTCal.write(ms, "CORRECTED_DATA", output)
    #    finalize(ms)
    #    wsclean("/dev/shm/mweastwood/getrfi-output.ms")
    #    mv("/dev/shm/mweastwood/getrfi-output.fits", "/dev/shm/mweastwood/getrfi-$idx.fits", remove_destination=true)
    #end
end

function _getrfi_residual(spw, path)
    data, meta = retry(load; n=3)(path, "data", "meta")
    beam = ConstantBeam()
    #position = Position(pos"WGS84",
    #                    1232.6294581335637meters,
    #                    -118.36229648059934degrees,
    #                    37.24861167954518degrees)
    #spectrum = RFISpectrum(meta.channels, fill(StokesVector(1, 0, 0, 0), length(meta.channels)))
    #source = RFISource("RFI C", position, spectrum)
    #source.spectrum = RFISpectrum(meta.channels, StokesVector.(getspec(data, meta, source)))
    #calibrations = peel!(data, meta, beam, [source], peeliter=1, maxiter=100, tolerance=1e-5, quiet=true)
    #model = genvis(meta, beam, source)
    #corrupt!(model, meta, calibrations[1])
    #model

    #if spw == 18
    #    N = 3
    #end
    #for idx = 1:N
    #    model = load(joinpath(getdir(spw), "rfi-$idx.jld"), "model")
    #    spectrum = zeros(HermitianJonesMatrix, 1)
    #    TTCal.getspec_internal!(spectrum, data, meta, model.data)
    #    J = spectrum[1]
    #    I = StokesVector(J).I
    #    for α = 1:Nbase(meta)
    #        model.data[α, 1] = model.data[α, 1] * J
    #    end
    #    subsrc!(data, model)
    #end

    data
end


function restore_rfi(spw, integrations)
    dir = getdir(spw)
    data = load(joinpath(dir, "visibilities.jld"), "data") :: Matrix{Complex128}
    flux = load(joinpath(dir, "rfi-light-curves.jld")) :: Matrix{Float64}
    data = data[:, integrations]
    flux = flux[N+1:end, integrations]
    Nsource, Ntime = size(flux)
    rfi = Visibilities[load(joinpath(dir, "rfi-$idx.jld"), "model") for idx = 1:Nsource]
    _restore_rfi(spw, data, flux, rfi)
    save(joinpath(dir, "visibilities-rfi-restored.jld"), "data")
end

function _restore_rfi(spw, data, flux, rfi)
    Nsource, Ntime = size(flux)
    Nbase = size(data, 1)
    p = Progress(Ntime)
    for idx = 1:Ntime
        for s = 1:Nsource
            model = rfi[s]
            for α = 1:Nbase
                I = 0.5*(model.data[α, 1].xx + model.data[α, 1].yy)
                data[α] += flux[s, idx]*I
            end
        end
        next!(p)
    end
    data
end

#function getrfi_prepare_measurement_sets(spw, integrations, sources)
#    dadas = listdadas(spw)
#    calinfo = readcals(spw)
#
#    idx = 1
#    N = length(integrations)
#    nextidx() = (myidx = idx; idx += 1; myidx)
#    idx2params(idx) = integrations[idx]
#
#    p = Progress(N, "Progress: ")
#    l = ReentrantLock()
#    increment_progress() = (lock(l); next!(p); unlock(l))
#
#    Lumberjack.info("Preparing the measurement sets")
#    @sync for worker in workers()
#        @async while true
#            myidx = nextidx()
#            myidx ≤ N || break
#            integration = idx2params(myidx)
#            Lumberjack.debug("Worker $worker is processing spw $spw integration $integration")
#            remotecall_fetch(getrfi_prepare_measurement_set, worker,
#                             spw, dadas[integration], sources, calinfo)
#            increment_progress()
#        end
#    end
#end
#
#function getrfi_prepare_measurement_set(spw, file, sources, calinfo)
#    ms, path = dada2ms(file)
#    caltimes, cal = calinfo
#
#    flag!(ms, spw)
#    data = TTCal.read(ms, "DATA")
#    meta = Metadata(ms)
#    beam = ConstantBeam()
#    frame = TTCal.reference_frame(meta)
#
#    # - find the nearest calibration in time and apply it
#    time = ms["TIME", 1]
#    idx = indmin(abs2(caltimes-time))
#    applycal!(data, meta, cal[idx])
#
#    # - flag short baselines
#    oldflags = copy(data.flags)
#    minuvw = 15.0
#    TTCal.flag_short_baselines!(data, meta, minuvw)
#
#    # - begin by classifying the sources based on how we intend to remove them
#    sources = TTCal.abovehorizon(frame, sources)
#    sources, spectra, directions = update_source_list(data, meta, sources)
#
#    # - pare down the dataset to just the channel of interest
#    β = 55
#    ν = meta.channels[β]
#    range = β:β
#    meta.channels = meta.channels[range]
#    data.data  = data.data[:, range]
#    data.flags = data.flags[:, range]
#
#    # - decide how we are going to remove each source
#    A, B = old_pick_removal_method(spw, frame, sources, ν)
#    rfi = old_pick_rfi_sources(spw, data, meta)
#    sun = old_get_the_sun(spw, data, meta)
#    A = [A; rfi; sun]
#
#    # - do the source removal
#    calibrations = peel!(data, meta, beam, A, peeliter=5, maxiter=30, tolerance=1e-3, quiet=true)
#    B, _, _ = update_source_list(data, meta, B)
#    subsrc!(data, meta, beam, B)
#
#    # - restore all of the RFI sources to the measurement set
#    for (idx, source) in enumerate(A)
#        if startswith(source.name, "RFI")
#            coherency = genvis(meta, beam, source)
#            corrupt!(coherency, meta, calibrations[idx])
#            data.data += coherency.data
#        end
#    end
#
#    output = joinpath(getdir(spw), "tmp", "getrfi-"*replace(basename(file), ".dada", ".jld"))
#    save(output, "meta", meta, "data", data)
#    finalize(ms)
#    rm(path, recursive=true)
#end
#
#function old_pick_removal_method(spw, frame, sources, ν)
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
#        elseif source.name == "Vir A"
#            if TTCal.isabovehorizon(frame, source, deg2rad(60))
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
#
#function old_pick_rfi_sources(spw, data, meta)
#    A = TTCal.Source[]
#    positions = [Position(pos"WGS84",
#                          1226.7091391887516meters,
#                          -118.3147833410907degrees,
#                          37.145402389570144degrees),
#                 Position(pos"WGS84",
#                          1214.248326037079meters,
#                          -118.3852914162684degrees,
#                          37.3078474772316degrees),
#                 Position(pos"WGS84",
#                          1232.6294581335637meters,
#                          -118.36229648059934degrees,
#                          37.24861167954518degrees),
#                 Position(pos"WGS84",
#                          1608.21583019197meters,
#                          -118.23417138204732degrees,
#                          37.06249388547446degrees)]
#    #Position(pos"WGS84", 1232.7690506698564meters, -118.37296747772183degrees, 37.24935118263112degrees),
#    for (idx, position) in enumerate(positions)
#        spectrum = RFISpectrum(meta.channels, fill(StokesVector(1, 0, 0, 0), length(meta.channels)))
#        source = RFISource("RFI $('A'+idx-1)", position, spectrum)
#        flux = getflux(data, meta, source)
#        if flux > 300
#            spectrum = RFISpectrum(meta.channels, fill(StokesVector(flux, 0, 0, 0), length(meta.channels)))
#            source = RFISource("RFI $('A'+idx-1)", position, spectrum)
#            push!(A, source)
#        end
#    end
#    A
#end
#
#function old_get_the_sun(spw, data, meta)
#    A = TTCal.Source[]
#    frame = TTCal.reference_frame(meta)
#    if TTCal.isabovehorizon(frame, Direction(dir"SUN"))
#        sun = fit_shapelets("Sun", meta, data, Direction(dir"SUN"), 5, deg2rad(0.2))
#        push!(A, sun)
#    end
#    A
#end

