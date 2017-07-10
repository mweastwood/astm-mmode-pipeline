function calibrate(spw, dataset, target)
    dir = getdir(spw)
    times, data, flags = load(joinpath(dir, "$target-$dataset-visibilities.jld"), "times", "data", "flags")

    if dataset == "100hr"
        day1_calibration_range =  3000: 5500
        day2_calibration_range =  9628:12128
        day3_calibration_range = 16256:18756
        day4_calibration_range = 22884:25384

        day1_calibration = solve_for_gain_calibration(spw, dataset, times, data, flags, day1_calibration_range)
        day2_calibration = solve_for_gain_calibration(spw, dataset, times, data, flags, day2_calibration_range)
        day3_calibration = solve_for_gain_calibration(spw, dataset, times, data, flags, day3_calibration_range)
        day4_calibration = solve_for_gain_calibration(spw, dataset, times, data, flags, day4_calibration_range)

        save(joinpath(dir, "gain-calibrations.jld"),
             "day1", day1_calibration, "day2", day2_calibration,
             "day3", day3_calibration, "day4", day4_calibration, compress=true)

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
    elseif dataset == "rainy"
        calibration_range = 1600:1700
        calibration = solve_for_gain_calibration(spw, dataset, times, data, flags, calibration_range)
        output = replace(replace(target, "smoothed-", ""), "visibilities", "gain-calibrations")
        save(joinpath(dir, output*".jld"), "calibration", calibration, compress=true)
        apply_the_calibration(data, flags, calibration)
    end

    save(joinpath(dir, "calibrated-$dataset-visibilities.jld"),
         "times", times, "data", data, "flags", flags, compress=true)

    nothing
end

"""
    solve_for_gain_calibration(spw, dataset, times data, flags, range)

Solve for the gain calibration of the given data. We will take a large track of data in order to
mitigate the effect of unmodeled sky components on the gain calibration.
"""
function solve_for_gain_calibration(spw, dataset, times, data, flags, range)
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

    model = Visibilities(Nbase, Ntime)
    meta = getmeta(spw, dataset)
    meta.channels = meta.channels[55:55]

    sources = readsources(joinpath(Common.workspace, "source-lists", "getdata-sources.json"))[1:2]
    if dataset == "rainy"
        # use measured flux for Cas
        if spw == 4
            cyg = 28371.8
            cas = 30624.7
        elseif spw == 6
            cyg = 25887.7
            cas = 28490.6
        elseif spw == 8
            cyg = 24129.8
            cas = 25420.0
        elseif spw == 10
            cyg = 22547.1
            cas = 23263.5
        elseif spw == 12
            cyg = 20911.2
            cas = 20799.3
        elseif spw == 14
            cyg = 19813.8
            cas = 19226.2
        elseif spw == 16
            cyg = 19051.0
            cas = 18337.2
        elseif spw == 18
            cyg = 18256.9
            cas = 17133.9
        end
        baars_cyg = StokesVector(TTCal.get_total_flux(sources[1], meta.channels[1])).I
        baars_cas = StokesVector(TTCal.get_total_flux(sources[2], meta.channels[1])).I
        scaleflux!(sources[2], (baars_cyg/cyg) * (cas/baars_cas), 0)
    end
    if dataset == "rainy"
        # use measured beam models
        if spw == 4
            coeff = [0.538556463745644
                     -0.46866163121041965
                     -0.02903632892950315
                     -0.008211454946665317
                     -0.02455123886166189
                     0.010200717351278811
                     -0.002733004888223435
                     0.012097962867146641
                     -0.010822907679258361]
        elseif spw == 6
            coeff = [0.5683128514113496
                     -0.46414332768707584
                     -0.049794949824191796
                     0.01956938394264056
                     -0.028882062170310224
                     -0.014311075332807512
                     -0.011543291444545006
                     0.00665053503527859
                     -0.009348228819604933]
        elseif spw == 8
            coeff = [0.5607524388115745
                     -0.45968937134966986
                     -0.04003477671659007
                     0.0054334058818740925
                     -0.029365565655034547
                     -0.00022684333835518863
                     -0.009772599099687997
                     0.007190059779729073
                     -0.01494324389373882]
        elseif spw == 10
            coeff = [0.5648697259136155
                     -0.45908927749490525
                     -0.03752995939112614
                     0.0033934821314708244
                     -0.030484384773088687
                     0.012225490320833442
                     -0.016913428790483902
                     -0.004324269518531433
                     -0.013275940628521119]
        elseif spw == 12
            coeff = [0.5647179136016398
                     -0.46118768245292385
                     -0.029017043660228167
                     -0.009711516291480747
                     -0.028346498468994164
                     0.03494942227085211
                     -0.025235050863329916
                     -0.011928112667488994
                     -0.013449331024941094]
        elseif spw == 14
            coeff = [0.5634780036856724
                     -0.45239381573418425
                     -0.020553945369180798
                     -0.0038610634839508044
                     -0.03766765187104518
                     0.034987669943576286
                     -0.03298552592171939
                     -0.017952720352740013
                     -0.014260163639469253]
        elseif spw == 16
            coeff = [0.554736976435005
                     -0.4446983513779896
                     -0.019835734224238583
                     -0.008902626634517375
                     -0.04089653832893597
                     0.02106671073637622
                     -0.02049607316869055
                     0.002052177725883946
                     -0.021225318022073877]
        elseif spw == 18
            coeff = [0.5494343726261235
                     -0.4422544222256613
                     -0.010377387323544141
                     -0.020193950880921727
                     -0.03933368453654855
                     0.03569618734453113
                     -0.020645215922528007
                     -0.0007547051500611155
                     -0.02480903125367872]
        end
        beam = ZernikeBeam(coeff)
    else
        beam = SineBeam()
    end

    # We need to generate the model visibilities one-by-one because TTCal will only do one
    # integration at a time. At this point we need to make sure TTCal knows that we only want a
    # single channel.

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

