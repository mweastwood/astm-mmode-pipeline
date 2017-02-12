function fitrfi_spw18(data, flags)
    spw = 18

    # create a measurement set to use for imaging
    dadas = listdadas(spw)
    ms, ms_path = dada2ms(dadas[1])
    finalize(ms)

    #@time meta, visibilities = fitrfi_sum_the_visibilities(spw, data, flags)
    #@time fitrfi_image_visibilities(spw, ms_path, "fitrfi-base", meta, visibilities)
    #save("/dev/shm/mweastwood/checkpoint1.jld", "meta", meta, "visibilities", visibilities)
    meta, visibilities = load("/dev/shm/mweastwood/checkpoint1.jld", "meta", "visibilities")

    #lat = 37.24861167954518
    #lon = -118.36229648059934
    #el = 1232.6294581335637
    #@time rfi1 = fitrfi_optimization(visibilities, meta, lat, lon, el)
    #@time visibilities1, calibrations1 = fitrfi_peel(meta, visibilities, [rfi1])
    #@time fitrfi_image_visibilities(spw, ms_path, "fitrfi-peeled-1", meta, visibilities1)
    #save("/dev/shm/mweastwood/checkpoint2.jld", "rfi1", rfi1, "visibilities1", visibilities1,
    #     "calibrations1", calibrations1)
    rfi1, visibilities1, calibrations1 = load("/dev/shm/mweastwood/checkpoint2.jld", "rfi1",
                                              "visibilities1", "calibrations1")

    #lat = 37.3078474772316
    #lon = -118.3852914162684
    #el = 1214.248326037079
    #@time rfi2 = fitrfi_optimization(visibilities1, meta, lat, lon, el)
    #@time visibilities2, calibrations2 = fitrfi_peel(meta, visibilities1, [rfi2, rfi2, rfi2, rfi2])
    #@time fitrfi_image_visibilities(spw, ms_path, "fitrfi-peeled-2", meta, visibilities2)
    #save("/dev/shm/mweastwood/checkpoint3.jld", "rfi2", rfi2, "visibilities2", visibilities2,
    #     "calibrations2", calibrations2)
    rfi2, visibilities2, calibrations2 = load("/dev/shm/mweastwood/checkpoint3.jld", "rfi2",
                                              "visibilities2", "calibrations2")

    # At this point we begin to start removing the smeared out tracks of Cyg A and Cas A
    #lat = 37.335911
    #lon = -118.394817
    #el = 1214.248326037079
    #@time rfi3 = fitrfi_optimization(visibilities2, meta, lat, lon, el)
    #@time visibilities3, calibrations3 = fitrfi_peel(meta, visibilities2, [rfi3, rfi3])
    #@time fitrfi_image_visibilities(spw, ms_path, "fitrfi-peeled-3", meta, visibilities3)

    #rfi = [rfi1, rfi2, rfi3]
    #@time fitrfi_image_models(spw, ms_path, meta, rfi)

    #fitrfi_image_corrupted_models(spw, ms_path, meta, [rfi3, rfi3], calibrations3)
    fitrfi_image_corrupted_models(spw, ms_path, meta, [rfi1, rfi2, rfi2, rfi2, rfi2], [calibrations1; calibrations2])

    fitrfi_output(spw, meta, [rfi1, rfi2, rfi2, rfi2, rfi2], [calibrations1; calibrations2])
end

function fitrfi_output(spw, meta, sources, calibrations)
    N = length(sources)
    xx = zeros(Complex128, Nbase(meta), N)
    yy = zeros(Complex128, Nbase(meta), N)
    beam = ConstantBeam()
    for idx = 1:N
        model = genvis(meta, beam, sources[idx])
        corrupt!(model, meta, calibrations[idx])
        for α = 1:Nbase(meta)
            xx[α, idx] = model.data[α, 1].xx
            yy[α, idx] = model.data[α, 1].yy
        end
    end
    dir = getdir(spw)
    save(joinpath(dir, "rfi-components.jld"), "xx", xx, "yy", yy)
    xx, yy
end

function fitrfi_sum_the_visibilities(spw, data, flags)
    _, Nbase, Ntime = size(data)
    meta = getmeta(spw)
    meta.channels = meta.channels[55:55]
    beam = ConstantBeam()
    visibilities = Visibilities(Nbase, 1)
    visibilities.flags[:] = true
    for idx = 1:Ntime, α = 1:Nbase
        if !flags[α, idx]
            xx = data[1, α, idx]
            yy = data[2, α, idx]
            visibilities.data[α, 1] += JonesMatrix(xx, 0, 0, yy)
            visibilities.flags[α, 1] = false
        end
    end
    TTCal.flag_short_baselines!(visibilities, meta, 15.0)
    meta, visibilities
end

function fitrfi_peel(meta, visibilities, sources)
    # we don't want to overwrite the old visibilities in case we want to undo this step
    visibilities = deepcopy(visibilities)
    beam = ConstantBeam()
    calibrations = peel!(visibilities, meta, beam, sources, peeliter=5, maxiter=100, tolerance=1e-3)
    visibilities, calibrations
end

function fitrfi_image_visibilities(spw, ms_path, image_name, meta, visibilities)
    beam = ConstantBeam()
    dir = getdir(spw)
    output_visibilities = Visibilities(Nbase(meta), 109)
    output_visibilities.flags[:] = true
    output_visibilities.flags[:, 55] = visibilities.flags[:, 1]
    output_visibilities.data[:, 55] = visibilities.data[:, 1]
    ms = Table(ms_path)
    TTCal.write(ms, "DATA", output_visibilities)
    finalize(ms)
    wsclean(ms_path, joinpath(dir, "tmp", image_name), j=8)
end

function fitrfi_image_models(spw, ms_path, meta, sources)
    beam = ConstantBeam()
    dir = getdir(spw)
    output_visibilities = Visibilities(Nbase(meta), 109)
    output_visibilities.flags[:] = true
    output_visibilities.flags[:, 55] = false
    for idx = 1:length(sources)
        model = genvis(meta, beam, sources[idx])
        output_visibilities.data[:, 55] = model.data[:, 1]
        ms = Table(ms_path)
        TTCal.write(ms, "DATA", output_visibilities)
        finalize(ms)
        wsclean(ms_path, joinpath(dir, "tmp", "fitrfi-pristine-model-$idx"), j=8)
    end
end

function fitrfi_image_corrupted_models(spw, ms_path, meta, sources, calibrations)
    beam = ConstantBeam()
    dir = getdir(spw)
    output_visibilities = Visibilities(Nbase(meta), 109)
    output_visibilities.flags[:] = true
    output_visibilities.flags[:, 55] = false
    for idx = 1:length(sources)
        model = genvis(meta, beam, sources[idx])
        corrupt!(model, meta, calibrations[idx])
        output_visibilities.data[:, 55] = model.data[:, 1]
        ms = Table(ms_path)
        TTCal.write(ms, "DATA", output_visibilities)
        finalize(ms)
        wsclean(ms_path, joinpath(dir, "tmp", "fitrfi-corrupted-model-$idx"), j=8)
    end
end

function fitrfi_optimization(visibilities, meta, lat, lon, el)
    opt = Opt(:LN_SBPLX, 3)
    max_objective!(opt, (x, g)->fitrfi_objective_function(visibilities, meta, x[1], x[2], x[3]))
    ftol_rel!(opt, 1e-10)
    minf, x, ret = optimize(opt, [lat, lon, el])
    lat = x[1]
    lon = x[2]
    el = x[3]

    position = Position(pos"WGS84", el*meters, lon*degrees, lat*degrees)
    spectrum = RFISpectrum(meta.channels, ones(StokesVector, Nfreq(meta)))
    rfi = RFISource("RFI", position, spectrum)
    stokes = StokesVector(getspec(visibilities, meta, rfi)[1])
    spectrum = RFISpectrum(meta.channels, [stokes])
    @show lat, lon, el, stokes
    rfi = RFISource("RFI", position, spectrum)
end

function fitrfi_objective_function(visibilities, meta, lat, lon, el)
    position = Position(pos"WGS84", el*meters, lon*degrees, lat*degrees)
    spectrum = RFISpectrum(meta.channels, [one(StokesVector)])
    rfi = RFISource("RFI", position, spectrum)
    flux = StokesVector(getspec(visibilities, meta, rfi)[1]).I
    flux
end

