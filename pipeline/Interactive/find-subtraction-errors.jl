function find_subtraction_errors_vir_a(spw, dataset, target)
    dir = getdir(spw)
    times, data, flags = load(joinpath(dir, "$target-$dataset-visibilities.jld"),
                              "times", "data", "flags")
    find_subtraction_errors_vir_a(spw, times, data, flags)
end

function find_subtraction_errors_vir_a(spw, dataset, times, data, flags)
    source = PointSource("Vir A", source_dictionary["Vir A"],
                         PowerLaw(1, 0, 0, 0, 1e6, [0.0]))
    flux = find_subtraction_errors(spw, dataset, times, data, flags, source)

    figure(1); clf()
    plot(1:length(times), flux, "ko")
end


function find_subtraction_errors(spw, dataset, times, data, flags, source)
    N = length(times)
    meta = getmeta(spw, dataset)
    meta.channels = meta.channels[55:55]
    meta.phase_center = Direction(dir"AZEL", 0degrees, 90degrees)
    flux = zeros(N)
    prg = Progress(N)
    for idx = 1:length(times)
        flux[idx] = _find_subtraction_errors(meta, times[idx], data[:, :, idx],
                                             flags[:, idx], source)
        next!(prg)
    end
    flux
end

function _find_subtraction_errors(meta, time, data, flags, source)
    meta.time = Epoch(epoch"UTC", time*seconds)
    visibilities = Visibilities(Nbase(meta), 1)
    for α = 1:Nbase(meta)
        visibilities.data[α, 1] = JonesMatrix(data[1, α], 0, 0, data[2, α])
        visibilities.flags[α, 1] = flags[α]
    end
    TTCal.flag_short_baselines!(visibilities, meta, 15.0)
    Calibration.getflux(visibilities, meta, source)
end

