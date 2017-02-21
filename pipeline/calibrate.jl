function calibrate(spw)
    dir = getdir(spw)
    times, phase, data = load(joinpath(dir, "raw-visibilities.jld"), "times", "phase", "data")

    flags = flag!(spw, data)
    sawtooth = smooth_out_the_sawtooth!(data, flags)

    # save the intermediate result for later analysis
    save(joinpath(dir, "smoothed-and-flagged-visibilities.jld"),
         "data", data, "flags", flags, "sawtooth", sawtooth, compress=true)

    day1_calibration_range =  3000: 5500
    day2_calibration_range =  9628:12128
    day3_calibration_range = 16256:18756
    day4_calibration_range = 22884:25384

    day1_calibration = solve_for_gain_calibration(spw, times, data, flags, day1_calibration_range)
    day2_calibration = solve_for_gain_calibration(spw, times, data, flags, day2_calibration_range)
    day3_calibration = solve_for_gain_calibration(spw, times, data, flags, day3_calibration_range)
    day4_calibration = solve_for_gain_calibration(spw, times, data, flags, day4_calibration_range)

    save(joinpath(dir, "gain-calibrations.jld"),
         "day1", day1_calibration, "day2", day2_calibration,
         "day3", day3_calibration, "day4", day4_calibration)

    # decide which integrations get which calibrations
    middle_of_day1 = round(Int, middle(day1_calibration_range))
    middle_of_day2 = round(Int, middle(day2_calibration_range))
    middle_of_day3 = round(Int, middle(day3_calibration_range))
    middle_of_day4 = round(Int, middle(day4_calibration_range))
    day1_day2_boundary = round(Int, middle(middle_of_day1:middle_of_day2))
    day2_day3_boundary = round(Int, middle(middle_of_day2:middle_of_day3))
    day3_day4_boundary = round(Int, middle(middle_of_day3:middle_of_day4))
    data_day1 = @view data[:, :, 1:day1_day2_boundary]
    data_day2 = @view data[:, :, day1_day2_boundary+1:day2_day3_boundary]
    data_day3 = @view data[:, :, day2_day3_boundary+1:day3_day4_boundary]
    data_day4 = @view data[:, :, day3_day4_boundary+1:end]
    flags_day1 = @view flags[:, 1:day1_day2_boundary]
    flags_day2 = @view flags[:, day1_day2_boundary+1:day2_day3_boundary]
    flags_day3 = @view flags[:, day2_day3_boundary+1:day3_day4_boundary]
    flags_day4 = @view flags[:, day3_day4_boundary+1:end]

    # and finally apply the calibration
    apply_the_calibration(data_day1, flags_day1, day1_calibration)
    apply_the_calibration(data_day2, flags_day2, day2_calibration)
    apply_the_calibration(data_day3, flags_day3, day3_calibration)
    apply_the_calibration(data_day4, flags_day4, day4_calibration)

    save(joinpath(dir, "calibrated-visibilities.jld"),
         "data", data, "flags", flags, compress=true)

    nothing
end

"""
    solve_for_gain_calibration(spw, data, flags, range)

Solve for the gain calibration of the given data. We will take a large track of data in order to
mitigate the effect of unmodeled sky components on the gain calibration.
"""
function solve_for_gain_calibration(spw, times, data, flags, range)
    Ntime = length(range)
    Nbase = size(data, 2)
    Nant = Nbase2Nant(Nbase)

    # TTCal currently doesn't natively support using multiple integrations to solve for the gain
    # calibration. However it does support using multiple frequency channels. So we will use a hack
    # to get this working.

    measured = Visibilities(Nbase, Ntime)
    for t = 1:Ntime, α = 1:Nbase
        measured.data[α, t] = JonesMatrix(data[1, α, range[t]], 0, 0, data[2, α, range[t]])
        measured.flags[α, t] = flags[α, range[t]]
    end

    sources = readsources(joinpath(sourcelists, "getdata-sources.json"))[1:2]
    beam = SineBeam()
    model = Visibilities(Nbase, Ntime)
    meta = getmeta(spw)

    # We need to generate the model visibilities one-by-one because TTCal will only do one
    # integration at a time. At this point we need to make sure TTCal knows that we only want a
    # single channel.

    meta.channels = meta.channels[55:55]
    for t = 1:Ntime
        meta.time = Epoch(epoch"UTC", times[range[t]]*seconds)
        meta.phase_center = Direction(dir"AZEL", 0degrees, 90degrees)
        _model = genvis(meta, beam, sources)
        model.data[:, t] = _model.data[:, 1]
    end

    # Now that we have all of the model visibilities, we can pretend that each integration is a
    # different frequency channel, but the frequency of each of these channels is the same.

    meta.channels = fill(meta.channels[1], Ntime)
    TTCal.flag_short_baselines!(measured, meta, 15.0)
    calibration = GainCalibration(Nant, 1)
    TTCal.solve_allchannels!(calibration, measured, model, meta, 100, 1e-3)

    calibration
end

"""
    apply_the_calibration(data, flags, calibration)

Apply the given calibration to the given dataset.
"""
function apply_the_calibration(data, flags, calibration)
    _, Nbase, Ntime = size(data)
    Nant = Nbase2Nant(Nbase)
    for ant1 = 1:Nant, ant2 = ant1:Nant
        Jxx1 = calibration.jones[ant1, 1].xx
        Jyy1 = calibration.jones[ant1, 1].yy
        Jxx2 = calibration.jones[ant2, 1].xx
        Jyy2 = calibration.jones[ant2, 1].yy
        f1 = calibration.flags[ant1, 1]
        f2 = calibration.flags[ant2, 1]
        α = baseline_index(ant1, ant2)
        for t = 1:Ntime
            data[1, α, t] /= Jxx1 * conj(Jxx2)
            data[2, α, t] /= Jyy1 * conj(Jyy2)
            flags[α, t] = flags[α, t] || f1 || f2
        end
    end
end

