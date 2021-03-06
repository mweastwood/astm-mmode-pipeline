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
        output_baseline_flags = Vector{Bool}[]
    end
    esc(output)
end

function fitrfi_getvis(spw, times, data, flags, dataset, integrations::Range, minuvw)
    fitrfi_sum_over_integrations(spw, times, data, flags, minuvw, dataset, integrations)
end

function fitrfi_getvis(spw, times, data, flags, dataset, integration::Integer, minuvw)
    fitrfi_pick_an_integration(spw, times, data, flags, minuvw, dataset, integration)
end

function fitrfi_pick_an_integration(spw, times, data, flags, minuvw, dataset, idx)
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
    TTCal.flag_short_baselines!(visibilities, meta, minuvw)
    meta, visibilities
end

function fitrfi_sum_over_integrations(spw, times, data, flags, minuvw, dataset, range)
    # TODO normalize by number of summed integrations (could differ per baseline)
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
    TTCal.flag_short_baselines!(visibilities, meta, minuvw)
    meta, visibilities
end

function fitrfi_sum_over_integrations_with_subtraction(spw, times, data, flags, minuvw,
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
        TTCal.flag_short_baselines!(temp, meta, minuvw)
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
    TTCal.flag_short_baselines!(visibilities, meta, minuvw)
    meta, visibilities
end

macro fitrfi_sum_over_integrations_with_subtraction(range, minuvw, sources...)
    quote
        meta, visibilities = fitrfi_sum_over_integrations_with_subtraction(spw, times, data, flags,
                                                                           $minuvw,
                                                                           dataset, $range, $sources)
        minuvw = $minuvw
    end |> esc
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
        fitrfi_image_corrupted_models(spw, ms_path, meta, sources, calibrations, visibilities.flags[:, 1],
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

function fitrfi_construct_sources(visibilities, meta, args)
    sources = TTCal.Source[]
    for arg in args
        if haskey(fitrfi_source_dictionary, arg)
            lat, lon, el = fitrfi_source_dictionary[arg]
            push!(sources, fitrfi_known_source(visibilities, meta, lat, lon, el))
        elseif isa(arg, String)
            push!(sources, fitrfi_getdata_source(arg, visibilities, meta))
        elseif isa(arg, Integer)
            unknown_sources = fill(fitrfi_unknown_source(), arg)
            sources = [sources; unknown_sources]
        end
    end
    sources
end

macro fitrfi_construct_sources(args...)
    output = quote
        sources = fitrfi_construct_sources(visibilities, meta, $args)
    end
    esc(output)
end

macro fitrfi_peel_sources()
    output = quote
        calibrations = fitrfi_peel(meta, visibilities, sources)
    end
    esc(output)
end

macro fitrfi_xx_only()
    output = quote
        for idx in eachindex(visibilities.data)
            J = visibilities.data[idx]
            visibilities.data[idx] = JonesMatrix(J.xx, 0, 0, 0)
        end
    end
    esc(output)
end

macro fitrfi_yy_only()
    output = quote
        for idx in eachindex(visibilities.data)
            J = visibilities.data[idx]
            visibilities.data[idx] = JonesMatrix(0, 0, 0, J.yy)
        end
    end
    esc(output)
end

function fitrfi_peel(meta, visibilities, sources, tolerance=1e-5, pol="both")
    @show pol
    for source in sources
        println(source)
    end
    beam = ConstantBeam()
    if pol == "xx"
        return fitrfi_peel_xx_only!(visibilities, meta, beam, sources, tolerance)
    elseif pol == "yy"
        return fitrfi_peel_yy_only!(visibilities, meta, beam, sources, tolerance)
    elseif pol == "both"
        return peel!(visibilities, meta, beam, sources, peeliter=10, maxiter=500,
                     tolerance=tolerance)
    end
end

function fitrfi_peel_xx_only!(visibilities, meta, beam, sources, tolerance)
    model = genvis(meta, beam, sources)
    for idx in eachindex(visibilities.data)
        J = visibilities.data[idx]
        Jm = model.data[idx]
        visibilities.data[idx] = JonesMatrix(J.xx, 0, 0, Jm.yy)
    end
    calibrations = peel!(visibilities, meta, beam, sources, peeliter=10, maxiter=500,
                         tolerance=tolerance)
    for idx in eachindex(visibilities.data)
        J = visibilities.data[idx]
        visibilities.data[idx] = JonesMatrix(J.xx, 0, 0, 0)
    end
    for calibration in calibrations, jdx in eachindex(calibration.jones)
        J = calibration.jones[jdx]
        calibration.jones[jdx] = DiagonalJonesMatrix(J.xx, 0)
    end
    calibrations
end

function fitrfi_peel_yy_only!(visibilities, meta, beam, sources, tolerance)
    model = genvis(meta, beam, sources)
    for idx in eachindex(visibilities.data)
        J = visibilities.data[idx]
        Jm = model.data[idx]
        visibilities.data[idx] = JonesMatrix(Jm.xx, 0, 0, J.yy)
    end
    calibrations = peel!(visibilities, meta, beam, sources, peeliter=10, maxiter=500,
                         tolerance=tolerance)
    for idx in eachindex(visibilities.data)
        J = visibilities.data[idx]
        visibilities.data[idx] = JonesMatrix(0, 0, 0, J.yy)
    end
    for calibration in calibrations, jdx in eachindex(calibration.jones)
        J = calibration.jones[jdx]
        calibration.jones[jdx] = DiagonalJonesMatrix(0, J.yy)
    end
    calibrations
end

macro fitrfi_select_components(range)
    output = quote
        for idx in $range
            push!(output_sources, sources[idx])
            push!(output_calibrations, calibrations[idx])
            push!(output_baseline_flags, visibilities.flags[:, 1])
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
                                      output_baseline_flags, "fitrfi-$target-$dataset")
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

    # remove columns of zeros
    xx = xx[:, squeeze(any(xx .!= 0, 1), 1)]
    yy = yy[:, squeeze(any(yy .!= 0, 1), 1)]

    output = joinpath(getdir(spw), filename*".jld")
    isfile(output) && rm(output)
    save(output, "xx", xx, "yy", yy)
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

make_vector_of_vectors{T}(vector::Vector{Vector{T}}, N) = vector
make_vector_of_vectors(vector::Vector, N) = fill(vector, N)

function fitrfi_image_corrupted_models(spw, ms_path, meta, sources, calibrations, flags, image_name)
    beam = ConstantBeam()
    dir = getdir(spw)
    _flags = make_vector_of_vectors(flags, length(sources))

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
        output_visibilities.flags[:, 55] = _flags[idx]
        ms = Table(ms_path)
        TTCal.write(ms, "DATA", output_visibilities)
        finalize(ms)
        wsclean(ms_path, joinpath(dir, "tmp", image_name*"-$idx"), j=8)
    end
end

macro fitrfi(integrations, sources, options...)
    _options = Dict{Symbol, Any}(eval(current_module(), option) for option in options)

    # First pack the data into a `Visibilities` object
    minuvw = get(_options, :minuvw, 15)
    output = quote
        meta, visibilities = fitrfi_getvis(spw, times, data, flags, dataset,
                                           $integrations, $minuvw)
    end

    # Remove previously fit RFI
    do_rm_rfi = haskey(_options, :rm_rfi)
    if do_rm_rfi
        rfi_selection = _options[:rm_rfi]
        push!(output.args, quote
            rm_rfi(meta, visibilities, output_sources[$rfi_selection],
                   output_calibrations[$rfi_selection])
        end)
    end

    # Fit for the RFI
    istest = get(_options, :test, false)
    pol = string(get(_options, :pol, :both))
    tolerance = get(_options, :tolerance, 1e-5)
    _sources = isa(sources, Symbol)? (sources,) : sources
    push!(output.args, quote
        sources, calibrations, baseline_flags = fitrfi_doit(spw, meta, visibilities, $_sources,
                                                            target, dataset, ms_path,
                                                            $tolerance, $istest, $pol)
    end)

    # If a baseline is flagged in the calibration, we will set it to zero. This can happen if the
    # calibration doesn't converge or if minuvw is set such that an antenna doesn't appear in any
    # baselines.
    push!(output.args, quote
        for calibration in calibrations, kdx in eachindex(calibration.jones, calibration.flags)
            if calibration.flags[kdx]
                calibration.jones[kdx] = zero(DiagonalJonesMatrix)
            end
        end
    end)

    # Output the results
    selection = _options[:select]
    push!(output.args, quote
        for idx in $selection
            push!(output_sources, sources[idx])
            push!(output_calibrations, calibrations[idx])
            push!(output_baseline_flags, baseline_flags)
        end
    end)

    esc(output)
end

function fitrfi_doit(spw, meta, visibilities, sources, target, dataset, ms_path, tolerance,
                     istest, pol)

    if pol == "xx"
        for idx in eachindex(visibilities.data)
            J = visibilities.data[idx]
            visibilities.data[idx] = JonesMatrix(J.xx, 0, 0, 0)
        end
    elseif pol == "yy"
        for idx in eachindex(visibilities.data)
            J = visibilities.data[idx]
            visibilities.data[idx] = JonesMatrix(0, 0, 0, J.yy)
        end
    end

    _sources = fitrfi_construct_sources(visibilities, meta, sources)
    _flags = visibilities.flags[:, 1]
    if istest
        output = "fitrfi-test-start-$target-$dataset"
        fitrfi_image_visibilities(spw, ms_path, output, meta, visibilities)
    end

    # Set Q to zero if we are doing one polarization.  Otherwise the model visibilities will have
    # zeros for one of xx or yy.  This makes the determinant zero and therefore makes the matrix
    # singular, which causes problems in TTCal.
    if pol != "both"
        for source in _sources
            scaleflux!(source, 2, 0)
        end
    end

    _calibrations = fitrfi_peel(meta, visibilities, _sources, tolerance, pol)

    if pol == "xx"
        for idx in eachindex(visibilities.data)
            J = visibilities.data[idx]
            visibilities.data[idx] = JonesMatrix(J.xx, 0, 0, 0)
        end
        for calibration in _calibrations, jdx in eachindex(calibration.jones)
            J = calibration.jones[jdx]
            calibration.jones[jdx] = DiagonalJonesMatrix(J.xx, 0)
        end
    elseif pol == "yy"
        for idx in eachindex(visibilities.data)
            J = visibilities.data[idx]
            visibilities.data[idx] = JonesMatrix(0, 0, 0, J.yy)
        end
        for calibration in _calibrations, jdx in eachindex(calibration.jones)
            J = calibration.jones[jdx]
            calibration.jones[jdx] = DiagonalJonesMatrix(0, J.yy)
        end
    end

    if istest
        output = "fitrfi-test-finish-$target-$dataset"
        fitrfi_image_visibilities(spw, ms_path, output, meta, visibilities)
        output = "fitrfi-test-component-$target-$dataset"
        fitrfi_image_corrupted_models(spw, ms_path, meta, _sources, _calibrations, _flags, output)
    end
    _sources, _calibrations, _flags
end

function fitrfi_spw04(times, data, flags, dataset, target)
    @fitrfi_preamble 4
    if dataset == "100hr"
    elseif dataset == "rainy"
        if target == "calibrated"
            # RFI
            @fitrfi 5157 (:A3, "Cas A", "Vir A") :select=>1
            @fitrfi 6205 ("Vir A", :A3, "Cas A") :select=>2
            @fitrfi 6626 (:A3, "Cyg A", "Vir A") :select=>1
            @fitrfi 6646 (:A3, "Cyg A", "Vir A", "Cas A") :select=>1
            @fitrfi 7118 (:A3, "Cyg A", "Cas A") :select=>1

            # Pickup
            @fitrfi 3357 ("Cas A", 1, "Cyg A") :select=>2 :pol=>:xx
            @fitrfi 6126 (1, "Vir A") :select=>1 :pol=>:xx

        elseif target == "rfi-restored-peeled"
            # Smeared
            @fitrfi 1:7756 A3 :select=>1

            # RFI
            @fitrfi 5157 A3 :select=>1
            @fitrfi 6205 A3 :select=>1
            @fitrfi 6626 A3 :select=>1
            @fitrfi 6646 A3 :select=>1
            @fitrfi 7118 A3 :select=>1

            # Pickup
            @fitrfi 3357 1 :select=>1 :pol=>:xx
            @fitrfi 6126 1 :select=>1 :pol=>:xx

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
            # RFI
            @fitrfi 6205 ("Vir A", :A3, "Cas A") :select=>2
            @fitrfi 6637 (:A3, "Cyg A", "Vir A", "Cas A") :select=>1
            @fitrfi 6650 (:A3, "Cyg A", "Cas A") :select=>1 :pol=>:xx
            @fitrfi 7079 (:A3, "Cyg A", "Cas A") :select=>1 :pol=>:xx
            @fitrfi 7118 (:A3, "Cyg A") :select=>1

        elseif target == "rfi-restored-peeled"
            # Smeared
            @fitrfi 1:7756 2 :select=>1:2

            # RFI
            @fitrfi 6205 A3 :select=>1
            @fitrfi 6637 A3 :select=>1
            @fitrfi 6650 A3 :select=>1 :pol=>:xx
            @fitrfi 7079 A3 :select=>1 :pol=>:xx
            @fitrfi 7118 A3 :select=>1
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
            # Smeared
            @fitrfi 1:7756 1 :select=>1

            # RFI
            @fitrfi 5175 (:A3, "Cas A", "Tau A", "Vir A") :select=>1 :rm_rfi=>1:1
            @fitrfi 6629 (:A3, "Cyg A", "Vir A", "Cas A") :select=>1 :rm_rfi=>1:1
            @fitrfi 7060 (:A3, "Cyg A") :select=>1 :rm_rfi=>1:1

            # Pickup
            @fitrfi 4916 ("Cas A", 1, "Tau A") :select=>2 :rm_rfi=>1:1 :pol=>:xx
            @fitrfi 6166 (1, "Vir A") :select=>1 :rm_rfi=>1:1 :minuvw=>4
            @fitrfi 6699 ("Cyg A", 1, "Vir A") :select=>2 :rm_rfi=>1:1 :minuvw=>5

        elseif target == "rfi-restored-peeled"
            # Smearaed
            @fitrfi 1:7756 3 :select=>1:3

            # RFI
            @fitrfi 5175 A3 :select=>1 :rm_rfi=>1:1
            @fitrfi 6629 A3 :select=>1 :rm_rfi=>1:1
            @fitrfi 7060 A3 :select=>1 :rm_rfi=>1:1

            # Pickup
            @fitrfi 4916 1 :select=>1 :rm_rfi=>1:1 :pol=>:xx
            @fitrfi 6166 1 :select=>1 :rm_rfi=>1:1 :minuvw=>4
            @fitrfi 6699 1 :select=>1 :rm_rfi=>1:1 :minuvw=>5
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
            # Smeared
            @fitrfi 1:7756 1 :select=>1

            # RFI
            @fitrfi 5175 (:A3, "Cas A", "Tau A", "Vir A") :select=>1 :rm_rfi=>1:1
            @fitrfi 6645 (:A3, "Cyg A", "Vir A") :select=>1 :rm_rfi=>1:1
            @fitrfi 7060 ("Cyg A", :A3, "Cas A") :select=>2 :rm_rfi=>1:1
            @fitrfi 7118 ("Cyg A", :A3, "Cas A") :select=>2 :rm_rfi=>1:1

            # Finally, something else interesting. This is a correlated noise component that gets in
            # the way of peeling Vir A.
            # (commented because I don't like how I'm fitting for this one -- it's sketchy)
            #@fitrfi_sum_over_integrations_with_subtraction 5755:5855 0 "Vir A" "Cas A"
            #@fitrfi_rm_rfi_so_far 1:1
            #@fitrfi_construct_sources 1
            #@fitrfi_test_start_image
            #@fitrfi_peel_sources
            #@fitrfi_test_finish_image
            #@fitrfi_select_components 1

        elseif target == "rfi-restored-peeled"
            # Smeared
            @fitrfi 1:7756 2 :select=>1:2

            # RFI
            @fitrfi 5175 A3 :select=>1 :rm_rfi=>1:1
            @fitrfi 6645 A3 :select=>1 :rm_rfi=>1:1
            @fitrfi 7060 A3 :select=>1 :rm_rfi=>1:1
            @fitrfi 7118 A3 :select=>1 :rm_rfi=>1:1

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
            # Smeared
            @fitrfi 1:7756 3 :select=>1:3

            # Pickup
            @fitrfi 6021 (1, "Vir A") :select=>1 :rm_rfi=>1:3
            @fitrfi 5857 (1, "Vir A") :select=>1 :rm_rfi=>1:3
            @fitrfi 6890 ("Cyg A", "Cas A", 1, "Vir A") :select=>3 :rm_rfi=>1:3

        elseif target == "rfi-restored-peeled"
            # Smeared
            @fitrfi 1:7756 5 :select=>1:5

            # Pickup
            @fitrfi 6021 1 :select=>1 :rm_rfi=>1:3
            @fitrfi 5857 1 :select=>1 :rm_rfi=>1:3
            @fitrfi 6890 1 :select=>1 :rm_rfi=>1:3

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
            # Smeared
            @fitrfi 1:7756 3 :select=>1:3

        elseif target == "rfi-restored-peeled"
            # Smeared
            @fitrfi 1:7756 3 :select=>1:3 :test=>true

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
            # Smeared
            @fitrfi 1:7756 2 :select=>1:2

            # RFI
            @fitrfi 5169 (:A3, "Cas A", "Tau A", "Vir A") :select=>1 :rm_rfi=>1:2 :test=>true

        elseif target == "rfi-restored-peeled"
            # Smeared
            @fitrfi 1:7756 2 :select=>1:2

            # RFI
            @fitrfi 5169 A3 :select=>1 :rm_rfi=>1:2
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
            # Smeared
            @fitrfi 1:7756 3 :select=>1:3 :test=>true

        elseif target == "rfi-restored-peeled"
            # Smeared
            @fitrfi 1:7756 4 :select=>1:4

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

