function fitrfi(spw, dataset, target)
    dir = getdir(spw)
    times, data, flags = load(joinpath(dir, "$target-$dataset-visibilities.jld"),
                              "times", "data", "flags")
    if spw == 4
        fitrfi_spw04(times, data, flags, dataset, target)
    elseif spw == 6
        fitrfi_spw06(times, data, flags, dataset, target)
    elseif spw == 8
        fitrfi_spw08(times, data, flags, dataset, target)
    elseif spw == 10
        fitrfi_spw10(times, data, flags, dataset, target)
    elseif spw == 12
        fitrfi_spw12(times, data, flags, dataset, target)
    elseif spw == 14
        fitrfi_spw14(times, data, flags, dataset, target)
    elseif spw == 16
        fitrfi_spw16(times, data, flags, dataset, target)
    elseif spw == 18
        fitrfi_spw18(times, data, flags, dataset, target)
    end
    nothing
end

macro fitrfi_preamble(spw)
    output = quote
        spw = $spw
        dadas = listdadas(spw, dataset)
        ms, ms_path = dada2ms(dadas[1], dataset)
        finalize(ms)

        output_sources = Source[]
        output_calibrations = GainCalibration[]
    end
    esc(output)
end

macro fitrfi_pick_an_integration(idx, flag_short=true)
    quote
        meta, visibilities = fitrfi_pick_an_integration(spw, times, data, flags, $flag_short,
                                                        dataset, $idx)
    end |> esc
end

function fitrfi_pick_an_integration(spw, times, data, flags, flag_short, dataset, idx)
    _, Nbase, Ntime = size(data)
    meta = getmeta(spw, dataset)
    meta.channels = meta.channels[55:55]
    meta.time = Epoch(epoch"UTC", times[idx]*seconds)
    meta.phase_center = Direction(dir"AZEL", 0degrees, 90degrees)
    beam = ConstantBeam()
    visibilities = Visibilities(Nbase, 1)
    visibilities.flags[:] = true
    for α = 1:Nbase
        xx = data[1, α, idx]
        yy = data[2, α, idx]
        visibilities.data[α, 1] = JonesMatrix(xx, 0, 0, yy)
        visibilities.flags[α, 1] = flags[α, idx]
    end
    if flag_short
        TTCal.flag_short_baselines!(visibilities, meta, 15.0)
    end
    meta, visibilities
end

macro fitrfi_sum_over_integrations(range, flag_short=true)
    quote
        meta, visibilities = fitrfi_sum_over_integrations(spw, times, data, flags, $flag_short,
                                                          dataset, $range)
    end |> esc
end

function fitrfi_sum_over_integrations(spw, times, data, flags, flag_short, dataset, range)
    _, Nbase, Ntime = size(data)
    meta = getmeta(spw, dataset)
    meta.channels = meta.channels[55:55]
    meta.time = Epoch(epoch"UTC", times[range[1]]*seconds)
    meta.phase_center = Direction(dir"AZEL", 0degrees, 90degrees)
    beam = ConstantBeam()
    visibilities = Visibilities(Nbase, 1)
    visibilities.flags[:] = true
    for idx in range, α = 1:Nbase
        if !flags[α, idx]
            xx = data[1, α, idx]
            yy = data[2, α, idx]
            visibilities.data[α, 1] += JonesMatrix(xx, 0, 0, yy)
            visibilities.flags[α, 1] = false
        end
    end
    if flag_short
        TTCal.flag_short_baselines!(visibilities, meta, 15.0)
    end
    meta, visibilities
end

macro fitrfi_sum_over_integrations_with_subtraction(range, flag_short, sources...)
    quote
        meta, visibilities = fitrfi_sum_over_integrations_with_subtraction(spw, times, data, flags,
                                                                           $flag_short,
                                                                           dataset, $range, $sources)
    end |> esc
end

function fitrfi_sum_over_integrations_with_subtraction(spw, times, data, flags, flag_short,
                                                       dataset, range, sources)
    _, Nbase, Ntime = size(data)
    meta = getmeta(spw, dataset)
    meta.channels = meta.channels[55:55]
    meta.phase_center = Direction(dir"AZEL", 0degrees, 90degrees)
    beam = ConstantBeam()
    visibilities = Visibilities(Nbase, 1)
    visibilities.flags[:] = true
    for idx in range
        all(flags[:, idx]) && continue
        meta.time = Epoch(epoch"UTC", times[idx]*seconds)
        temp = Visibilities(Nbase, 1)
        temp.flags[:] = true
        for α = 1:Nbase
            xx = data[1, α, idx]
            yy = data[2, α, idx]
            temp.data[α, 1] = JonesMatrix(xx, 0, 0, yy)
            temp.flags[α, 1] = flags[α, idx]
        end
        TTCal.flag_short_baselines!(temp, meta, 15.0)
        for name in sources
            source = fitrfi_getdata_source(name, temp, meta)
            subsrc!(temp, meta, ConstantBeam(), source)
        end
        for α = 1:Nbase
            if !flags[α, idx]
                visibilities.data[α, 1] += temp.data[α, 1]
                visibilities.flags[α, 1] = false
            end
        end
    end
    if flag_short
        TTCal.flag_short_baselines!(visibilities, meta, 15.0)
    end
    meta, visibilities
end

function fitrfi_getdata_source(name, visibilities, meta)
    getdata_sources = readsources(joinpath(dirname(@__FILE__), "..", "..", "workspace", "source-lists",
                                           "getdata-sources.json"))
    source = filter(source -> source.name == name, getdata_sources)[1]
    source, I, Q, dir = update(visibilities, meta, source)
    source
end

macro fitrfi_test_start_image()
    quote
        fitrfi_image_visibilities(spw, ms_path, "fitrfi-test-start-$target-$dataset", meta, visibilities)
    end |> esc
end

macro fitrfi_test_finish_image()
    quote
        fitrfi_image_visibilities(spw, ms_path, "fitrfi-test-finish-$target-$dataset", meta, visibilities)
        fitrfi_image_corrupted_models(spw, ms_path, meta, sources, calibrations,
                                      "fitrfi-test-component-$target-$dataset")
    end |> esc
end

const fitrfi_source_dictionary = Dict(
    :A => (37.145402389570144, -118.3147833410907,  1226.7091391887516), # Big Pine
    :B => (37.3078474772316,   -118.3852914162684,  1214.248326037079),  # Bishop
    :C => (37.24861167954518,  -118.36229648059934, 1232.6294581335637), # Keough's Hot Springs
    :D => (37.06249388547446,  -118.23417138204732, 1608.21583019197),
    # the following locations were eye-balled by Marin
    :A2 => (37.143397, -118.322727, 1226.709), # another Big Pine source
    :B2 => (37.323000, -118.401953, 1214.248326037079), # the northern most source in the triplet
    :B3 => (37.320125, -118.377464, 1214.248326037079), # the middle source in the triplet
    # fit for with the position fitting routine
    :A3 => (37.17025133416173,  -118.32196666958995, 1895.923202819064),
    :B4 => (37.712871601687155, -118.92190463586564, 1647.8143169306663),
    :E => (37.27751649756355, -118.37534090029699, 726.6254751399765)
)

function fitrfi_known_source(visibilities, meta, lat, lon, el)
    position = Position(pos"WGS84", el*meters, lon*degrees, lat*degrees)
    spectrum = RFISpectrum(meta.channels, ones(StokesVector, 1))
    rfi = RFISource("RFI", position, spectrum)
    stokes = StokesVector(getspec(visibilities, meta, rfi)[1])
    spectrum = RFISpectrum(meta.channels, [stokes])
    RFISource("RFI", position, spectrum)
end

function fitrfi_unknown_source()
    direction = Direction(dir"AZEL", 0degrees, 90degrees)
    spectrum = PowerLaw(0.1, 0, 0, 0, 1e6, [0.0])
    PointSource("RFI", direction, spectrum)
end

macro fitrfi_construct_sources(args...)
    output = quote
        sources = TTCal.Source[]
    end
    for arg in args
        if haskey(fitrfi_source_dictionary, arg)
            lat, lon, el = fitrfi_source_dictionary[arg]
            expr = :(push!(sources, fitrfi_known_source(visibilities, meta, $lat, $lon, $el)))
            push!(output.args, expr)
        elseif isa(arg, String)
            expr = :(push!(sources, fitrfi_getdata_source($arg, visibilities, meta)))
            push!(output.args, expr)
        elseif isa(arg, Integer)
            unknown_sources = fill(fitrfi_unknown_source(), arg)
            expr = :(sources = [sources; $unknown_sources])
            push!(output.args, expr)
        end
    end
    esc(output)
end

macro fitrfi_peel_sources()
    output = quote
        calibrations = fitrfi_peel(meta, visibilities, sources)
    end
    esc(output)
end

function fitrfi_peel(meta, visibilities, sources)
    for source in sources
        println(source)
    end
    beam = ConstantBeam()
    peel!(visibilities, meta, beam, sources, peeliter=10, maxiter=500, tolerance=1e-5)
end

macro fitrfi_select_components(range)
    output = quote
        for idx in $range
            push!(output_sources, sources[idx])
            push!(output_calibrations, calibrations[idx])
        end
    end
    esc(output)
end

macro fitrfi_rm_rfi_so_far(range)
    output = quote
        rm_rfi(meta, visibilities, output_sources[$range], output_calibrations[$range])
    end
    esc(output)
end

macro fitrfi_finish()
    output = quote
        if length(output_sources) == 0
            meta = getmeta(spw, dataset)
            meta.channels = meta.channels[55:55]
            meta.phase_center = Direction(dir"AZEL", 0degrees, 90degrees)
        end
        fitrfi_image_corrupted_models(spw, ms_path, meta, output_sources, output_calibrations,
                                      "fitrfi-$target-$dataset")
        xx, yy = fitrfi_output(spw, meta, output_sources, output_calibrations,
                               "fitrfi-$target-$dataset")
    end
    esc(output)
end

function fitrfi_output(spw, meta, sources, calibrations, filename)
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
    save(joinpath(dir, "$filename.jld"), "xx", xx, "yy", yy)
    xx, yy
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

function fitrfi_image_corrupted_models(spw, ms_path, meta, sources, calibrations, image_name)
    beam = ConstantBeam()
    dir = getdir(spw)

    # delete existing images
    files = readdir(joinpath(dir, "tmp"))
    filter!(file->startswith(file, image_name), files)
    filter!(file->endswith(file, ".fits"), files)
    for file in files
        rm(joinpath(dir, "tmp", file))
    end

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
        wsclean(ms_path, joinpath(dir, "tmp", image_name*"-$idx"), j=8)
    end
end

function fitrfi_spw04(times, data, flags, dataset, target)
    @fitrfi_preamble 4
    if dataset == "100hr"
    elseif dataset == "rainy"
        if target == "calibrated"
            # This is a piece of horizon RFI that shows up from Big Pine. It's extremely bright
            # though, so a single integration is sufficient to take it out.
            @fitrfi_pick_an_integration 6646
            @fitrfi_construct_sources A3 "Cyg A" "Vir A" "Cas A"
            @fitrfi_peel_sources
            @fitrfi_select_components 1

            # This is the same RFI source as above, but the subtraction doesn't do a particularly
            # good job. So we'll fit for it again.
            @fitrfi_pick_an_integration 6205
            @fitrfi_construct_sources "Vir A" A3 "Cas A"
            @fitrfi_peel_sources
            @fitrfi_select_components 2

            # Same RFI source, same problem.
            @fitrfi_pick_an_integration 7118
            @fitrfi_construct_sources A3 "Cyg A" "Cas A"
            @fitrfi_peel_sources
            @fitrfi_select_components 1

            # Same RFI source, same problem.
            @fitrfi_pick_an_integration 5157
            @fitrfi_construct_sources A3 "Cas A" "Vir A"
            @fitrfi_peel_sources
            @fitrfi_select_components 1
        elseif target == "rfi-restored-peeled"
        else
            error("unknown target")
        end
    else
        error("unknown dataset")
    end
    @fitrfi_finish
end

function fitrfi_spw06(times, data, flags, dataset, target)
    @fitrfi_preamble 6
    if dataset == "100hr"
    elseif dataset == "rainy"
        if target == "calibrated"
            # Similar to spw04 above, this is the same piece of horizon RFI. Once again it is very
            # bright.
            @fitrfi_pick_an_integration 6637
            @fitrfi_construct_sources A3 "Cyg A" "Vir A" "Cas A"
            @fitrfi_peel_sources
            @fitrfi_select_components 1

            # Cas A fails to peel on this integration and it's unclear why. My hypothesis is that
            # the bright RFI wasn't subtracted very well, but it seems to be fine. We'll fit for it
            # again anyway, but it's not obvious why I should have to.
            @fitrfi_pick_an_integration 6205
            @fitrfi_construct_sources "Vir A" A3 "Cas A"
            @fitrfi_test_start_image
            @fitrfi_peel_sources
            @fitrfi_test_finish_image
            @fitrfi_select_components 2
        elseif target == "rfi-restored-peeled"
        else
            error("unknown target")
        end
    else
        error("unknown dataset")
    end
    @fitrfi_finish
end

function fitrfi_spw08(times, data, flags, dataset, target)
    @fitrfi_preamble 8
    if dataset == "100hr"
    elseif dataset == "rainy"
        if target == "calibrated"
            @fitrfi_sum_over_integrations 1:7756
            @fitrfi_construct_sources 1
            @fitrfi_peel_sources
            @fitrfi_select_components 1

            # Big Pine RFI Peak #1
            @fitrfi_pick_an_integration 5175
            @fitrfi_rm_rfi_so_far 1:1
            @fitrfi_construct_sources A3 "Cas A" "Tau A" "Vir A"
            @fitrfi_peel_sources
            @fitrfi_select_components 1

            # Big Pine RFI Peak #2
            @fitrfi_pick_an_integration 6629
            @fitrfi_rm_rfi_so_far 1:1
            @fitrfi_construct_sources A3 "Cyg A" "Vir A" "Cas A"
            @fitrfi_peel_sources
            @fitrfi_select_components 1

            # Big Pine RFI Peak #3
            @fitrfi_pick_an_integration 7060
            @fitrfi_rm_rfi_so_far 1:1
            @fitrfi_construct_sources A3 "Cyg A"
            @fitrfi_test_start_image
            @fitrfi_peel_sources
            @fitrfi_test_finish_image
            @fitrfi_select_components 1


            # TODO: recheck this integration, I forgot to @fitrfi_rm_rfi_so_far
            # it's possible that this component I got is the one above

            ## There is a correlated noise component that gets in the way of peeling Cas A on this
            ## integration. There is also an RFI source on the horizon, but it gets mixed up with Cen
            ## A if I try to pick that out on this integration.
            #@fitrfi_pick_an_integration 6195
            #@fitrfi_construct_sources "Vir A" 1 "Cas A"
            #@fitrfi_test_start_image
            #@fitrfi_peel_sources
            #@fitrfi_test_finish_image
            #@fitrfi_select_components 2
        elseif target == "rfi-restored-peeled"
        else
            error("unknown target")
        end
    else
        error("unknown dataset")
    end
    @fitrfi_finish
end

function fitrfi_spw10(times, data, flags, dataset, target)
    @fitrfi_preamble 10
    if dataset == "100hr"
    elseif dataset == "rainy"
        if target == "calibrated"
            @fitrfi_sum_over_integrations 1:7756 false
            @fitrfi_construct_sources 1
            @fitrfi_peel_sources
            @fitrfi_select_components 1

            # This is that piece of RFI from Big Pine showing up again. Here it intereferes with Cas
            # A getting peeled correctly.
            @fitrfi_pick_an_integration 7118
            @fitrfi_rm_rfi_so_far 1:1
            @fitrfi_construct_sources "Cyg A" A3 "Cas A"
            @fitrfi_peel_sources
            @fitrfi_select_components 2

            # The Big Pine RFI strikes back.
            @fitrfi_pick_an_integration 6645
            @fitrfi_rm_rfi_so_far 1:1
            @fitrfi_construct_sources A3 "Cyg A" "Vir A"
            @fitrfi_peel_sources
            @fitrfi_select_components 1

            # Return of the Big Pine RFI
            @fitrfi_pick_an_integration 7060
            @fitrfi_rm_rfi_so_far 1:1
            @fitrfi_construct_sources "Cyg A" A3 "Cas A"
            @fitrfi_peel_sources
            @fitrfi_select_components 2

            # Big Pine...
            @fitrfi_pick_an_integration 5175
            @fitrfi_rm_rfi_so_far 1:1
            @fitrfi_construct_sources A3 "Cas A" "Tau A" "Vir A"
            @fitrfi_peel_sources
            @fitrfi_select_components 1

            # Finally, something else interesting. This is a correlated noise component that gets in
            # the way of peeling Vir A.
            @fitrfi_sum_over_integrations_with_subtraction 5755:5855 false "Vir A" "Cas A"
            @fitrfi_rm_rfi_so_far 1:1
            @fitrfi_construct_sources 1
            @fitrfi_test_start_image
            @fitrfi_peel_sources
            @fitrfi_test_finish_image
            @fitrfi_select_components 1

        elseif target == "rfi-restored-peeled"
        else
            error("unknown target")
        end
    else
        error("unknown dataset")
    end
    @fitrfi_finish
end

function fitrfi_spw12(times, data, flags, dataset, target)
    @fitrfi_preamble 12
    if dataset == "100hr"
    elseif dataset == "rainy"
        if target == "calibrated"
            @fitrfi_sum_over_integrations 1:7756
            @fitrfi_construct_sources 3
            @fitrfi_peel_sources
            @fitrfi_select_components 1:3

            # This is a correlated noise component that dominates over Vir A and interferes with it
            # being peeled.
            @fitrfi_pick_an_integration 5857
            @fitrfi_rm_rfi_so_far 1:3
            @fitrfi_construct_sources 1 "Vir A"
            @fitrfi_peel_sources
            @fitrfi_select_components 1

            # This is another correlated noise component that gets in the way of Vir A.
            @fitrfi_pick_an_integration 6890
            @fitrfi_rm_rfi_so_far 1:3
            @fitrfi_construct_sources "Cyg A" "Cas A" 1 "Vir A"
            @fitrfi_test_start_image
            @fitrfi_peel_sources
            @fitrfi_test_finish_image
            @fitrfi_select_components 3

        elseif target == "rfi-restored-peeled"
        else
            error("unknown target")
        end
    else
        error("unknown dataset")
    end
    @fitrfi_finish
end

function fitrfi_spw14(times, data, flags, dataset, target)
    @fitrfi_preamble 14
    if dataset == "100hr"
    elseif dataset == "rainy"
        if target == "calibrated"
            @fitrfi_sum_over_integrations 1:7756
            @fitrfi_construct_sources 3
            @fitrfi_test_start_image
            @fitrfi_peel_sources
            @fitrfi_test_finish_image
            @fitrfi_select_components 1:3
        elseif target == "rfi-restored-peeled"
        else
            error("unknown target")
        end
    else
        error("unknown dataset")
    end
    @fitrfi_finish
end

function fitrfi_spw16(times, data, flags, dataset, target)
    @fitrfi_preamble 16
    if dataset == "100hr"
    elseif dataset == "rainy"
        if target == "calibrated"
            @fitrfi_sum_over_integrations 1:7756
            @fitrfi_construct_sources 2
            @fitrfi_peel_sources
            @fitrfi_select_components 1:2

            ## This is a bright piece of RFI that shows up towards Big Pine. It causes problems for
            ## peeling Cas A. Peeling really wants to take pieces of Tau A and Vir A here, and the
            ## solution doesn't actually converge, but the solution looks ok so I'm leaving it for
            ## now.
            @fitrfi_pick_an_integration 5169
            @fitrfi_rm_rfi_so_far 1:2
            @fitrfi_construct_sources A3 "Cas A" "Tau A" "Vir A"
            @fitrfi_test_start_image
            @fitrfi_peel_sources
            @fitrfi_test_finish_image
            @fitrfi_select_components 1

        elseif target == "rfi-restored-peeled"
            ## The third component doesn't converge here, but it looks reasonable. I suspect this is
            ## due to one polarization not converging and the other one looks fine.
            ##@fitrfi_sum_over_integrations 1:7756
            ##@fitrfi_construct_sources 3
            ##@fitrfi_peel_sources
            ##@fitrfi_select_components 1:3

            #@fitrfi_pick_an_integration 5169
            ##@fitrfi_rm_rfi_so_far 1:3
            #@fitrfi_construct_sources A3
            #@fitrfi_test_start_image
            ##@fitrfi_peel_sources
            ##@fitrfi_test_finish_image
            ##@fitrfi_select_components 1
        else
            error("unknown target")
        end
    else
        error("unknown dataset")
    end
    @fitrfi_finish
end

function fitrfi_spw18(times, data, flags, dataset, target)
    @fitrfi_preamble 18
    if dataset == "100hr"
    elseif dataset == "rainy"
        if target == "calibrated"
            @fitrfi_sum_over_integrations 1:7756
            @fitrfi_construct_sources 3
            @fitrfi_peel_sources
            @fitrfi_select_components 1:3

            # This component causes Cas A to fail to peel in integration 911 (and nearby). However
            # it seems impossible to separate this component from Cas by considering a single
            # integration, and if you use multiple integrations it is difficult to get peeling to
            # converge. However, if you use multiple integrations and do not flag short baselines
            # things seem to work out.
            @fitrfi_sum_over_integrations_with_subtraction 811:911 false "Cyg A" "Cas A"
            @fitrfi_rm_rfi_so_far 1:3
            @fitrfi_construct_sources 1
            @fitrfi_peel_sources
            @fitrfi_select_components 1

        elseif target == "rfi-restored-peeled"
        else
            error("unknown target")
        end
    else
        error("unknown dataset")
    end
    @fitrfi_finish
end

"""
    fitrfi_get_new_coordinates(spw, data, flags, lat, lon, el)

Fit for the coordinates of a new RFI source in the given data.
"""
function fitrfi_get_new_coordinates(spw, data, flags, lat, lon, el)
    meta, visibilities = fitrfi_sum_the_visibilities(spw, data, flags)

    opt = Opt(:LN_SBPLX, 3)
    max_objective!(opt, (x, g)->fitrfi_objective_function(visibilities, meta, x[1], x[2], x[3]))
    lower_bounds!(opt, [lat-1, lon-1, 0])
    upper_bounds!(opt, [lat+1, lon+1, 3000])
    xtol_rel!(opt, 1e-15)
    ftol_rel!(opt, 1e-10)
    minf, x, ret = optimize(opt, [lat, lon, el])

    lat = x[1]
    lon = x[2]
    el = x[3]
    @show minf lat lon el ret
end

function fitrfi_objective_function(visibilities, meta, lat, lon, el)
    position = Position(pos"WGS84", el*meters, lon*degrees, lat*degrees)
    spectrum = RFISpectrum(meta.channels, [one(StokesVector)])
    rfi = RFISource("RFI", position, spectrum)
    flux = StokesVector(getspec(visibilities, meta, rfi)[1]).I
    flux
end

