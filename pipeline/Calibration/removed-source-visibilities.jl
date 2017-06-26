function removed_source_visibilities(spw, dataset, target, source_name)
    dir = getdir(spw)
    filename = joinpath(dir, "$target-$dataset-visibilities.jld")
    peeling_data, times, flags = load(filename, "peeling-data", "times", "flags")
    _removed_source_visibilities(spw, dataset, target, source_name, peeling_data, times, flags)
end

function _removed_source_visibilities(spw, dataset, target, source_name, peeling_data, times, flags)
    meta = getmeta(spw, dataset)
    meta.channels = meta.channels[55:55]
    meta.phase_center = Direction(dir"AZEL", 0degrees, 90degrees)
    Ntime = length(times)
    data = zeros(Complex128, 2, Nbase(meta), Ntime)
    p = Progress(Ntime)
    for integration = 1:Ntime
        meta.time = Epoch(epoch"UTC", times[integration]*seconds)
        my_peeling_data = peeling_data[integration]
        source_names = [source.name for source in my_peeling_data.sources]
        indices = find(source_names .== source_name)
        length(indices) > 0 || @goto skip
        length(indices) < 2 || error("too many sources matched #$integration")
        !all(flags[:, integration]) || @goto skip
        source_number = indices[1]
        source = my_peeling_data.sources[source_number]
        my_peeling_data.I[source_number] != 0 || @goto skip
        if source_number in my_peeling_data.to_peel
            # source was peeled
            calibration = my_peeling_data.calibrations[source_number .== my_peeling_data.to_peel][1]
            data[:, :, integration] = genvis_peeled(meta, source, calibration)
        elseif source_number in [my_peeling_data.to_sub_bright; my_peeling_data.to_sub_faint]
            # source was subtracted
            data[:, :, integration] = genvis_subtracted(meta, source)
        elseif source_number in my_peeling_data.to_fit_with_shapelets
            # source was removed with a shapelet fit
            data[:, :, integration] = genvis_subtracted(meta, source)
        end
        if any(isnan(data[:,:,integration]))
            @show my_peeling_data source source_number
            error("NaNs #$integration")
        end
        @label skip
        next!(p)
    end

    dir = getdir(spw)
    filename = "$(lowercase(replace(source_name, " ", "")))-$target-$dataset-visibilities.jld"
    save(joinpath(dir, filename), "times", times, "data", data, "flags", flags, compress=true)
end

function genvis_subtracted(meta, source)
    visibilities = genvis(meta, source)
    xx = getfield.(visibilities.data[:, 1], 1)
    yy = getfield.(visibilities.data[:, 1], 4)
    output = zeros(Complex128, 2, Nbase(visibilities))
    output[1, :] = xx
    output[2, :] = yy
    output
end

function genvis_peeled(meta, source, calibration)
    visibilities = genvis(meta, source)
    corrupt!(visibilities, meta, calibration)
    xx = getfield.(visibilities.data[:, 1], 1)
    yy = getfield.(visibilities.data[:, 1], 4)
    output = zeros(Complex128, 2, Nbase(visibilities))
    output[1, :] = xx
    output[2, :] = yy
    output
end

