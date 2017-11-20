function source_from_name(name)
    PointSource(name, source_dictionary[name], PowerLaw(1, 0, 0, 0, 1e6, [0.0]))
end

function rfi_from_name(spw, dataset, name)
    meta = getmeta(spw, dataset)
    meta.channels = meta.channels[55:55]
    lat, lon, el = Calibration.fitrfi_source_dictionary[Symbol(name)]
    position = Position(pos"WGS84", el*meters, lon*degrees, lat*degrees)
    spectrum = RFISpectrum(meta.channels, ones(StokesVector, 1))
    RFISource("RFI", position, spectrum)
end

function find_subtraction_errors(spw, dataset, target, name)
    dir = getdir(spw)
    times, data, flags = load(joinpath(dir, "$target-$dataset-visibilities.jld"),
                              "times", "data", "flags")
    find_subtraction_errors(spw, times, data, flags, name)
end

function find_subtraction_errors(spw, dataset, times, data, flags, name)
    if haskey(source_dictionary, name)
        source = source_from_name(name)
    else
        source = rfi_from_name(spw, dataset, name)
    end
    flux = _find_subtraction_errors(spw, dataset, times, data, flags, source)

    figure(); clf()
    plot(1:length(times), flux, "k-")
    title(source.name)
end

function _find_subtraction_errors(spw, dataset, times, data, flags, source)
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

function _find_subtraction_errors(meta::Metadata, time, data, flags, source)
    meta.time = Epoch(epoch"UTC", time*seconds)
    visibilities = Visibilities(Nbase(meta), 1)
    for α = 1:Nbase(meta)
        visibilities.data[α, 1] = JonesMatrix(data[1, α], 0, 0, data[2, α])
        visibilities.flags[α, 1] = flags[α]
    end
    TTCal.flag_short_baselines!(visibilities, meta, 15.0)
    Calibration.getflux(visibilities, meta, source)
end

