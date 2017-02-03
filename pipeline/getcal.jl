# TODO: use multiple integrations to help mitigate the effects of
#       scintillation on the flux scale

function getcal(spw, N=4)
    dadas = listdadas(spw)
    #integration = 3698 # 8:00 am (15:00 UTC time)
    integration = 3500 # go earlier to make sure the Sun isn't up yet
    Ntime = 6628 # the number of 13 second integrations in a sidereal day
    for idx = 1:N
        getcal(spw, dadas[integration + (idx-1)*Ntime], idx)
    end
end

function getcal(spw, input, idx)
    Lumberjack.info("Solving for gain calibration with $input")
    ms, path = dada2ms(input)
    local meta, cal, shavings, time
    try
        flag!(ms, spw)
        major = readsources(joinpath(sourcelists, "getcal-major-sources.json"))
        minor = readsources(joinpath(sourcelists, "getcal-minor-sources.json"))

        data = TTCal.read(ms, "DATA")
        flags = deepcopy(data.flags)
        meta = Metadata(ms)
        TTCal.flag_short_baselines!(data, meta, 20.0)
        time = ms["TIME", 1]

        first_iteration!(data, meta, major, minor)
        #subsequent_iteration!(data, meta, major, minor)

        model = genvis(meta, ConstantBeam(), [major; minor])
        cal = gaincal(data, meta, ConstantBeam(), [major; minor], maxiter=50, tolerance=1e-3)
        applycal!(data, meta, cal)
        shavings = shave!(data, meta, ConstantBeam(), major)
        subsrc!(data, meta, ConstantBeam(), minor)

        #data.flags = flags
        TTCal.write(ms, "MODEL_DATA", model, apply_flags=false)
        TTCal.write(ms, "CORRECTED_DATA", data)

    finally
        finalize(ms)
    end

    dir = joinpath(getdir(spw), "calibrations")
    isdir(dir) || mkdir(dir)
    cal_name = joinpath(dir, "$idx.jld")
    ms_name  = joinpath(dir, "$idx.ms")

    #Lumberjack.info("Saving the calibration to $cal_name")
    #save(cal_name, "cal", cal, "time", time, "shavings", shavings)
    Lumberjack.info("Saving the measurement set to $ms_name")
    cp(path, ms_name, remove_destination=true)
    Lumberjack.info("Creating an image of the measurement set at $ms_name")
    wsclean(ms_name, weight="uniform")

    rm(path, recursive=true)

    nothing
end

function first_iteration!(data, meta, major, minor)
    mydata = deepcopy(data)
    calibration = gaincal(mydata, meta, SineBeam(), major, maxiter=50, tolerance=1e-3)
    applycal!(mydata, meta, calibration)

    for jdx = 1:length(major)
        @show major[jdx]
        _source, _spec, _dir = update(mydata, meta, major[jdx])
        major[jdx] = _source
        @show major[jdx]
    end

    shave!(mydata, meta, ConstantBeam(), major, peeliter=3, maxiter=30, tolerance=1e-3)

    rfi = pick_rfi_sources(mydata, meta)
    shavings = shave!(mydata, meta, ConstantBeam(), rfi, peeliter=3, maxiter=30, tolerance=1e-3)
    for jdx = 1:length(rfi)
        to_subtract = genvis(meta, ConstantBeam(), rfi[jdx])
        corrupt!(to_subtract, meta, shavings[jdx])
        corrupt!(to_subtract, meta, calibration)
        subsrc!(data, to_subtract)
    end

    for jdx = 1:length(minor)
        @show minor[jdx]
        _source, _spec, _dir = update(mydata, meta, minor[jdx])
        minor[jdx] = _source
        @show minor[jdx]
    end

    calibration
end

function subsequent_iteration!(data, meta, major, minor)
    mydata = deepcopy(data)
    calibration = gaincal(mydata, meta, ConstantBeam(), [major; minor], maxiter=50, tolerance=1e-3)
    applycal!(mydata, meta, calibration)

    for jdx = 1:length(major)
        @show major[jdx]
        _source, _spec, _dir = update(mydata, meta, major[jdx])
        major[jdx] = _source
        @show major[jdx]
    end

    subsrc!(mydata, meta, ConstantBeam(), major)

    for jdx = 1:length(minor)
        @show minor[jdx]
        _source, _spec, _dir = update(mydata, meta, minor[jdx])
        minor[jdx] = _source
        @show minor[jdx]
    end

    calibration
end

function pick_rfi_sources(data, meta)
    output = Source[]
    rfi = [Position(pos"WGS84", 1226.7091391887516meters, -118.3147833410907degrees, 37.145402389570144degrees),
           Position(pos"WGS84", 1214.248326037079meters, -118.3852914162684degrees, 37.3078474772316degrees),
           Position(pos"WGS84", 1232.7690506698564meters, -118.37296747772183degrees, 37.24935118263112degrees),
           Position(pos"WGS84", 1608.21583019197meters, -118.23417138204732degrees, 37.06249388547446degrees)]
    for idx = 1:length(rfi)
        position = rfi[idx]
        spectrum = RFISpectrum(meta.channels, fill(StokesVector(1, 0, 0, 0), length(meta.channels)))
        source = RFISource("RFI $('A'+idx-1)", position, spectrum)
        stokes = StokesVector.(getspec(data, meta, source))
        spectrum = RFISpectrum(meta.channels, stokes)
        source.spectrum = spectrum
        flux = mean(stokes[idx].I for idx = 1:length(stokes))
        @show flux
        if flux > 500
            push!(output, source)
        end
    end
    output
end

function readcals(spw)
    dir = joinpath(getdir(spw), "calibrations")
    calibrations = readdir(dir)
    filter!(calibrations) do file
        endswith(file, ".jld")
    end
    sort!(calibrations)
    times = Float64[]
    cal = GainCalibration[]
    for calibration in calibrations
        mycal, mytime = load(joinpath(dir, calibration), "cal", "time")
        push!(cal, mycal)
        push!(times, mytime)
    end
    times, cal
end

