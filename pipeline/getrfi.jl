function getrfi()
    spw = 18
    #integrations = 3315:4971
    integrations = 1:26262
    restore_rfi(spw, integrations)
    sum_and_image(spw, integrations)
    ##integrations = 3315:3315
    #sources = readsources(joinpath(sourcelists, "getdata-sources.json"))[1:2]
    ##getrfi_prepare_measurement_sets(spw, integrations, sources)
    #getrfi_residual(spw, integrations)
end

function restore_rfi(spw, integrations)
    dir = getdir(spw)
    flux = load(joinpath(dir, "rfi-light-curves.jld"), "light-curves")
    data, flags = load(joinpath(dir, "visibilities.jld"), "data", "flags")
    data, flags = _restore_rfi(spw, integrations, data, flags, flux)
    save(joinpath(dir, "visibilities-rfi-restored.jld"), "data", data, "flags", flags, compress=true)
end

function _restore_rfi(spw, integrations, data, flags, flux)
    Nsource, Ntime = size(flux)
    flux = flux[Nsource+1:end, integrations]
    data = data[:, :, integrations]
    flags = flags[:, integrations]
    rfi = Visibilities[load(joinpath(getdir(spw), "old-rfi", "rfi-$idx.jld"), "model") for idx = 1:Nsource]
    _restore_rfi_inner_loop(spw, data, flux, rfi)
    data, flags
end

function _restore_rfi_inner_loop(spw, data, flux, rfi)
    Nsource, Ntime = size(flux)
    Nbase = size(data, 1)
    for idx = 1:Ntime
        for s = 1:Nsource
            model = rfi[s]
            for α = 1:Nbase
                J = flux[s, idx]*model.data[α, 1]
                data[1, α, idx] += J.xx
                data[2, α, idx] += J.yy
            end
        end
    end
    data
end

function sum_and_image(spw, integrations)
    dir = getdir(spw)
    data, flags = load(joinpath(dir, "visibilities-rfi-restored.jld"), "data", "flags")
    _sum_and_image(spw, integrations, data, flags)
end

function _sum_and_image(spw, integrations, data, flags)
    Nbase = size(data, 2)
    Nfreq = 109
    output = Visibilities(Nbase, Nfreq)
    output.flags[:] = true
    _sum_and_image_inner_loop(output, spw, integrations, data, flags)
    if !isdir("/dev/shm/mweastwood/getrfi-output.ms")
        create_template_ms(spw, joinpath(getdir(spw), "tmp", "getrfi-output.ms"), 50)
        cp(joinpath(getdir(spw), "tmp", "getrfi-output.ms"), "/dev/shm/mweastwood/getrfi-output.ms")
    end
    ms = Table("/dev/shm/mweastwood/getrfi-output.ms")
    TTCal.write(ms, "CORRECTED_DATA", output)
    TTCal.write(ms, "BACKUP_DATA", output)
    unlock(ms)
    finalize(ms)
    wsclean("/dev/shm/mweastwood/getrfi-output.ms")
end

function _sum_and_image_inner_loop(output, spw, integrations, data, flags)
    _, Nbase, Ntime = size(data)
    integration_flags = load(joinpath(getdir(spw), "integration-flags.jld"), "flags")
    for idx = 1:Ntime
        for α = 1:Nbase
            if integration_flags[integrations[idx]]
                continue
            end
            if !flags[α, idx]
                J = JonesMatrix(data[1, α, idx], 0, 0, data[2, α, idx])
                output.data[α, 55] += J
                output.flags[α, 55] = false
            end
        end
    end
end

function svd_clean_the_rfi()
    ms = Table("/dev/shm/mweastwood/getrfi-output.ms")
    data = TTCal.read(ms, "BACKUP_DATA")
    xx = zeros(Complex128, 256, 256)
    α = 1
    for ant1 = 1:256, ant2 = ant1:256
        if ant1 == ant2
            xx[ant1, ant2] = real(data.data[α, 55].xx)
        else
            xx[ant1, ant2] = data.data[α, 55].xx
            xx[ant2, ant1] = conj(xx[ant1, ant2])
        end
        α += 1
    end

    D, V = eig(Hermitian(xx))
    for idx = 1:10
        D[256-idx+1] = 0
        xx′ = V*diagm(D)*V'

        output = Visibilities(Nbase(data), 109)
        output.flags[:] = true
        output.flags[:, 55] = data.flags[:, 55]
        α = 1
        for ant1 = 1:256, ant2 = ant1:256
            output.data[α, 55] = JonesMatrix(xx′[ant1, ant2], 0, 0, xx′[ant1, ant2])
            α += 1
        end

        TTCal.write(ms, "CORRECTED_DATA", output)
        finalize(ms)

        wsclean("/dev/shm/mweastwood/getrfi-output.ms")
        mv("/dev/shm/mweastwood/getrfi-output.fits", "/dev/shm/mweastwood/getrfi-svd-$idx.fits", remove_destination=true)
        ms = Table("/dev/shm/mweastwood/getrfi-output.ms")
    end
end

function peel_rfi_sources(spw)
    ms = Table("/dev/shm/mweastwood/getrfi-output.ms")
    #data = TTCal.read(ms, "CORRECTED_DATA")
    #TTCal.write(ms, "BACKUP_DATA", data)
    data = TTCal.read(ms, "BACKUP_DATA")
    meta = Metadata(ms)
    data.data = data.data[:, 55:55]
    data.flags = data.flags[:, 55:55]
    meta.channels = meta.channels[55:55]

    positions = [Position(pos"WGS84",
                          1226.7091391887516meters,
                          -118.3147833410907degrees,
                          37.145402389570144degrees),
                 Position(pos"WGS84",
                          1214.248326037079meters,
                          -118.3852914162684degrees,
                          37.3078474772316degrees),
                 Position(pos"WGS84",
                          1232.6294581335637meters,
                          -118.36229648059934degrees,
                          37.24861167954518degrees),
                 Position(pos"WGS84",
                          1608.21583019197meters,
                          -118.23417138204732degrees,
                          37.06249388547446degrees)]

    sources = TTCal.Source[]
    for idx in (3, 3, 2, 2, 1)#, 2)
        position = positions[idx]
        spectrum = RFISpectrum(meta.channels, fill(StokesVector(1, 0, 0, 0), length(meta.channels)))
        source = RFISource("RFI $('A' + (idx-1))", position, spectrum)
        #source.spectrum = RFISpectrum(meta.channels, StokesVector.(getspec(data, meta, source)))
        push!(sources, source)
    end
    calibrations = peel!(data, meta, ConstantBeam(), sources, peeliter=5, maxiter=100, tolerance=1e-5, quiet=false)

    models = Visibilities[]
    for (idx, source) in enumerate(sources)
        model = genvis(meta, ConstantBeam(), source)
        corrupt!(model, meta, calibrations[idx])
        vec = getfield.(model.data[:, 1], 1)
        λ = norm(vec)
        model.data /= λ
        push!(models, model)
    end

    save(joinpath(getdir(spw), "rfi-models.jld"), "models", models)

    output = Visibilities(Nbase(meta), 109)
    output.flags[:] = true
    output.data[:, 55] = data.data
    output.flags[:, 55] = data.flags

    TTCal.write(ms, "CORRECTED_DATA", output)
    finalize(ms)

    wsclean("/dev/shm/mweastwood/getrfi-output.ms")
end

#function getrfi_residual(spw, integrations)
#    dadas = listdadas(spw)
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
#    meta = getmeta(spw)
#    meta.channels = meta.channels[55:55]
#    #xx = zeros(Complex128, Nant(meta), N)
#    #yy = zeros(Complex128, Nant(meta), N)
#    #function save_cal(cal, idx)
#    #    for ant = 1:Nant(meta)
#    #        xx[ant, idx] = cal.jones[ant, 1].xx
#    #        yy[ant, idx] = cal.jones[ant, 1].yy
#    #    end
#    #end
#    data = Visibilities(Nbase(meta), 1)
#    add_to_data(mydata) = data.data += mydata.data
#    set_flags(mydata) = data.flags = mydata.flags
#
#    integration_flags = load(joinpath(getdir(spw), "integration-flags.jld"), "flags")
#
#    Lumberjack.info("Measuring residuals after peeling")
#    @sync for worker in workers()
#        @async while true
#            myidx = nextidx()
#            myidx ≤ N || break
#            integration = idx2params(myidx)
#            if !integration_flags[integration]
#                file = dadas[integration]
#                path = joinpath(getdir(spw), "tmp", "getrfi-"*replace(basename(file), ".dada", ".jld"))
#                #mycal = remotecall_fetch(_getrfi_residual, worker, path)
#                #save_cal(mycal, myidx)
#                #if myidx == 750
#                #    mydata = remotecall_fetch(_getrfi_residual, worker, spw, path)
#                #    add_to_data(mydata)
#                #    set_flags(mydata)
#                #end
#                mydata = remotecall_fetch(_getrfi_residual, worker, spw, path)
#                add_to_data(mydata)
#                myidx == 1 && set_flags(mydata)
#            end
#            increment_progress()
#        end
#    end
#    save("/dev/shm/mweastwood/getrfi-data.jld", "data", data)
#    #data = load("/dev/shm/mweastwood/getrfi-data.jld", "data")
#
#    #positions = [Position(pos"WGS84",
#    #                      1226.7091391887516meters,
#    #                      -118.3147833410907degrees,
#    #                      37.145402389570144degrees),
#    #             Position(pos"WGS84",
#    #                      1214.248326037079meters,
#    #                      -118.3852914162684degrees,
#    #                      37.3078474772316degrees),
#    #             Position(pos"WGS84",
#    #                      1232.6294581335637meters,
#    #                      -118.36229648059934degrees,
#    #                      37.24861167954518degrees),
#    #             Position(pos"WGS84",
#    #                      1608.21583019197meters,
#    #                      -118.23417138204732degrees,
#    #                      37.06249388547446degrees)]
#
#    #sources = TTCal.Source[]
#    #for idx in (3, 2, 2)
#    #    position = positions[idx]
#    #    spectrum = RFISpectrum(meta.channels, fill(StokesVector(1, 0, 0, 0), length(meta.channels)))
#    #    source = RFISource("RFI $('A' + (idx-1))", position, spectrum)
#    #    source.spectrum = RFISpectrum(meta.channels, StokesVector.(getspec(data, meta, source)))
#    #    push!(sources, source)
#    #end
#    #calibrations = peel!(data, meta, ConstantBeam(), sources, peeliter=5, maxiter=100, tolerance=1e-5, quiet=true)
#
#    #for (idx, source) in enumerate(sources)
#    #    @show idx
#    #    model = genvis(meta, ConstantBeam(), source)
#    #    corrupt!(model, meta, calibrations[idx])
#    #    str = @sprintf("spw%02d", spw)
#    #    save(joinpath(getdir(spw), "rfi-$idx.jld"), "model", model)
#    #end
#
#    output = Visibilities(Nbase(meta), 109)
#    output.flags[:] = true
#    output.data[:, 55] = data.data
#    output.flags[:, 55] = data.flags
#
#    if !isdir("/dev/shm/mweastwood/getrfi-output.ms")
#        cp(joinpath(getdir(spw), "tmp", "getrfi-output.ms"), "/dev/shm/mweastwood/getrfi-output.ms")
#    end
#    ms = Table("/dev/shm/mweastwood/getrfi-output.ms")
#    TTCal.write(ms, "CORRECTED_DATA", output)
#    unlock(ms)
#    finalize(ms)
#
#    wsclean("/dev/shm/mweastwood/getrfi-output.ms")
#    ##mv("/dev/shm/mweastwood/getrfi-output.fits", "/dev/shm/mweastwood/getrfi-image.fits", remove_destination=true)
#
#    #for idx = 2:2#(idx, source) in enumerate(sources)
#    #    @show idx
#    #    ms = Table("/dev/shm/mweastwood/getrfi-output.ms")
#    #    model = load(joinpath(getdir(spw), "rfi-$idx.jld"), "model")
#    #    output.data[:, 55] = model.data
#    #    TTCal.write(ms, "CORRECTED_DATA", output)
#    #    finalize(ms)
#    #    wsclean("/dev/shm/mweastwood/getrfi-output.ms")
#    #    mv("/dev/shm/mweastwood/getrfi-output.fits", "/dev/shm/mweastwood/getrfi-$idx.fits", remove_destination=true)
#    #end
#end
#
#function _getrfi_residual(spw, path)
#    data, meta = retry(load; n=3)(path, "data", "meta")
#    beam = ConstantBeam()
#    #position = Position(pos"WGS84",
#    #                    1232.6294581335637meters,
#    #                    -118.36229648059934degrees,
#    #                    37.24861167954518degrees)
#    #spectrum = RFISpectrum(meta.channels, fill(StokesVector(1, 0, 0, 0), length(meta.channels)))
#    #source = RFISource("RFI C", position, spectrum)
#    #source.spectrum = RFISpectrum(meta.channels, StokesVector.(getspec(data, meta, source)))
#    #calibrations = peel!(data, meta, beam, [source], peeliter=1, maxiter=100, tolerance=1e-5, quiet=true)
#    #model = genvis(meta, beam, source)
#    #corrupt!(model, meta, calibrations[1])
#    #model
#
#    #if spw == 18
#    #    N = 3
#    #end
#    #for idx = 1:N
#    #    model = load(joinpath(getdir(spw), "rfi-$idx.jld"), "model")
#    #    spectrum = zeros(HermitianJonesMatrix, 1)
#    #    TTCal.getspec_internal!(spectrum, data, meta, model.data)
#    #    J = spectrum[1]
#    #    I = StokesVector(J).I
#    #    for α = 1:Nbase(meta)
#    #        model.data[α, 1] = model.data[α, 1] * J
#    #    end
#    #    subsrc!(data, model)
#    #end
#
#    data
#end

