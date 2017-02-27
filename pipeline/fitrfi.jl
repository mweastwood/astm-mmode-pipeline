function fitrfi(spw)
    dir = getdir(spw)
    data, flags = load(joinpath(dir, "calibrated-visibilities.jld"), "data", "flags")
    if spw == 4
        return fitrfi_spw04(data, flags)
    elseif spw == 6
        return fitrfi_spw06(data, flags)
    elseif spw == 8
        return fitrfi_spw08(data, flags)
    elseif spw == 10
        return fitrfi_spw10(data, flags)
    elseif spw == 12
        return fitrfi_spw12(data, flags)
    elseif spw == 14
        return fitrfi_spw14(data, flags)
    elseif spw == 16
        return fitrfi_spw16(data, flags)
    elseif spw == 18
        return fitrfi_spw18(data, flags)
    end
end

function source_dictionary(name)
    if name == "A"
        # Big Pine
        lat = 37.145402389570144
        lon = -118.3147833410907
        el = 1226.7091391887516
    elseif name == "B"
        # Bishop
        lat = 37.3078474772316
        lon = -118.3852914162684
        el = 1214.248326037079
    elseif name == "C"
        # Keough's Hot Springs
        lat = 37.24861167954518
        lon = -118.36229648059934
        el = 1232.6294581335637
    elseif name == "D"
        lat = 37.06249388547446
        lon = -118.23417138204732
        el = 1608.21583019197
    else
        Lumberjack.error("unknown source")
    end
    lat, lon, el
end

function fitrfi_spw04(data, flags)
end

function fitrfi_spw06(data, flags)
end

function fitrfi_spw08(data, flags)
end

function fitrfi_spw10(data, flags)
end

function fitrfi_spw12(data, flags)
    spw = 12
    dadas = listdadas(spw)
    ms, ms_path = dada2ms(dadas[1])
    finalize(ms)

    meta, visibilities0 = fitrfi_start(spw, data, flags, ms_path, checkpoint=true)

    lat, lon, el = source_dictionary("B")
    N = 3
    rfi1, visibilities1, calibrations1 = fitrfi_do_source(spw, meta, visibilities0, ms_path,
                                                          lat, lon, el, 1, N, checkpoint=true)

    rfi = rfi1
    calibrations = calibrations1
    fitrfi_image_corrupted_models(spw, ms_path, meta, rfi, calibrations)
    fitrfi_output(spw, meta, rfi1, calibrations)
end

function fitrfi_spw14(data, flags)
    spw = 14
    dadas = listdadas(spw)
    ms, ms_path = dada2ms(dadas[1])
    finalize(ms)

    meta, visibilities0 = fitrfi_start(spw, data, flags, ms_path, checkpoint=true)

    lat, lon, el = source_dictionary("A")
    N = 1
    rfi1, visibilities1, calibrations1 = fitrfi_do_source(spw, meta, visibilities0, ms_path,
                                                          lat, lon, el, 1, N, checkpoint=true)

    lat, lon, el = source_dictionary("C")
    N = 1
    rfi2, visibilities2, calibrations2 = fitrfi_do_source(spw, meta, visibilities1, ms_path,
                                                          lat, lon, el, 2, N, checkpoint=true)

    lat, lon, el = source_dictionary("B")
    N = 3
    rfi3, visibilities3, calibrations3 = fitrfi_do_source(spw, meta, visibilities2, ms_path,
                                                          lat, lon, el, 3, N, checkpoint=true)

    rfi = [rfi1; rfi2; rfi3]
    calibrations = [calibrations1; calibrations2; calibrations3]
    fitrfi_image_corrupted_models(spw, ms_path, meta, rfi, calibrations)
    fitrfi_output(spw, meta, rfi1, calibrations)
end

function fitrfi_spw16(data, flags)
    spw = 16
    dadas = listdadas(spw)
    ms, ms_path = dada2ms(dadas[1])
    finalize(ms)

    meta, visibilities0 = fitrfi_start(spw, data, flags, ms_path, checkpoint=true)

    lat, lon, el = source_dictionary("A")
    N = 2
    rfi1, visibilities1, calibrations1 = fitrfi_do_source(spw, meta, visibilities0, ms_path,
                                                          lat, lon, el, 1, N, checkpoint=true)

    lat, lon, el = source_dictionary("B")
    N = 2
    rfi2, visibilities2, calibrations2 = fitrfi_do_source(spw, meta, visibilities1, ms_path,
                                                          lat, lon, el, 2, N, checkpoint=true)

    #lat, lon, el = source_dictionary("D")
    #N = 2
    #rfi3, visibilities3, calibrations3 = fitrfi_do_source(spw, meta, visibilities2, ms_path,
    #                                                      lat, lon, el, 3, N, checkpoint=false)

    fitrfi_image_corrupted_models(spw, ms_path, meta, [rfi1; rfi2], [calibrations1; calibrations2])
    fitrfi_output(spw, meta, [rfi1; rfi2], [calibrations1; calibrations2])
end

function fitrfi_spw18(data, flags)
    spw = 18
    dadas = listdadas(spw)
    ms, ms_path = dada2ms(dadas[1])
    finalize(ms)

    meta, visibilities0 = fitrfi_start(spw, data, flags, ms_path, checkpoint=true)

    lat, lon, el = source_dictionary("C")
    N = 1
    rfi1, visibilities1, calibrations1 = fitrfi_do_source(spw, meta, visibilities0, ms_path,
                                                          lat, lon, el, 1, N, checkpoint=true)

    lat, lon, el = source_dictionary("B")
    N = 4
    rfi2, visibilities2, calibrations2 = fitrfi_do_source(spw, meta, visibilities1, ms_path,
                                                          lat, lon, el, 2, N, checkpoint=true)

    #lat = 37.335911
    #lon = -118.394817
    #el = 1214.248326037079
    #N = 2
    #rfi3, visibilities3, calibrations3 = fitrfi_do_source(spw, meta, visibilities2, ms_path,
    #                                                      lat, lon, el, 3, N, checkpoint=false)

    fitrfi_image_corrupted_models(spw, ms_path, meta, [rfi1; rfi2], [calibrations1; calibrations2])
    fitrfi_output(spw, meta, [rfi1; rfi2], [calibrations1; calibrations2])
end

function fitrfi_start(spw, data, flags, ms_path; checkpoint=false) :: Tuple{Metadata, Visibilities}
    checkpoint_path = "/dev/shm/mweastwood/fitrfi-start-checkpoint.jld"
    if checkpoint && isfile(checkpoint_path)
        myspw = load(checkpoint_path, "spw")
        if myspw == spw
            meta, visibilities = load(checkpoint_path, "meta", "visibilities")
            return meta, visibilities
        end
    end
    meta, visibilities = fitrfi_sum_the_visibilities(spw, data, flags)
    fitrfi_image_visibilities(spw, ms_path, "fitrfi-start", meta, visibilities)
    save(checkpoint_path, "spw", spw, "meta", meta, "visibilities", visibilities)
    meta, visibilities
end

function fitrfi_do_source(spw, meta, visibilities, ms_path, lat, lon, el, idx, N; checkpoint=false)
    checkpoint_path = @sprintf("/dev/shm/mweastwood/fitrfi-checkpoint-%02d.jld", idx)
    if checkpoint && isfile(checkpoint_path)
        myspw = load(checkpoint_path, "spw")
        if myspw == spw
            rfi_list, visibilities, calibrations = load(checkpoint_path, "rfi", "visibilities", "calibrations")
            return rfi_list, visibilities, calibrations
        end
    end
    rfi = fitrfi_optimization(visibilities, meta, lat, lon, el)
    rfi_list = fill(rfi, N)
    visibilities, calibrations = fitrfi_peel(meta, visibilities, rfi_list)
    fitrfi_image_visibilities(spw, ms_path, @sprintf("fitrfi-peeled-%02d", idx), meta, visibilities)
    save(checkpoint_path, "spw", spw, "rfi", rfi_list, "visibilities", visibilities, "calibrations", calibrations)
    rfi_list, visibilities, calibrations
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

