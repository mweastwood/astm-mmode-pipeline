function fix_flux_scale(dataset, filename="map-wiener-filtered")
    spws = 4:2:18
    frequencies = getfrequencies(spws, dataset)
    psfs = loadpsf_peak(spws, dataset)
    maps = readmaps(spws, dataset, filename)
    x, y, z = unit_vectors(nside(maps[1]))

    names = collect(keys(calibrators))
    perley = perley_flux_calibrators()
    scaife = scaife_flux_calibrators()
    baars  = baars_flux_calibrators()

    my_measure_spectrum(name) = measure_spectrum(calibrators[name], psfs, maps, x, y, z, dataset)
    my_model_spectrum(dict, name) = [dict[name](ν).I for ν in frequencies]

    measured_fluxes = Dict(name => my_measure_spectrum(name) for name in names)
    perley_fluxes   = Dict(name => my_model_spectrum(perley, name) for name in keys(perley))
    scaife_fluxes   = Dict(name => my_model_spectrum(scaife, name) for name in keys(scaife))
    baars_fluxes    = Dict(name => my_model_spectrum(baars, name) for name in keys(baars))

    #for (idx, name) in enumerate(names)
    #    direction = calibrators[name]
    #    measured = measure_spectrum(direction, psfs, maps, x, y, z, dataset)
    #
    #    figure(idx); clf()
    #    plot(frequencies/1e6, measured, "ko")
    #    if name in keys(perley)
    #        spectrum = perley[name]
    #        model = [spectrum(ν).I for ν in frequencies]
    #        plot(frequencies/1e6, model, "k-")
    #    end
    #    if name in keys(scaife)
    #        spectrum = scaife[name]
    #        model = [spectrum(ν).I for ν in frequencies]
    #        plot(frequencies/1e6, model, "k--")
    #    end
    #    if name in keys(baars)
    #        spectrum = baars[name]
    #        model = [spectrum(ν).I for ν in frequencies]
    #        plot(frequencies/1e6, model, "k-.")
    #    end
    #    xlim(35, 75)
    #    ylimits = gca()[:get_ylim]()
    #    ylim(0, ylimits[2])
    #    title(name)
    #    grid("on")
    #end

    meta = getmeta(4, "rainy")
    frame = TTCal.reference_frame(meta)
    save(joinpath("../workspace", "source-fluxes-$filename.jld"), "calibrators", calibrators,
         "measured_fluxes", measured_fluxes, "perley_fluxes", perley_fluxes,
         "scaife_fluxes", scaife_fluxes, "baars_fluxes", baars_fluxes, "frame", frame)

end

function measure_spectrum(direction, psfs, maps, x, y, z, dataset)
    meta  = getmeta(4, dataset)
    frame = TTCal.reference_frame(meta)
    itrf  = measure(frame, direction, dir"ITRF")
    vec = [itrf.x, itrf.y, itrf.z]
    θ = π/2 - latitude(itrf)
    aperture = Int[]
    annulus = Int[]
    for idx = 1:length(maps[1])
        vec′ = LibHealpix.pix2vec_ring(nside(maps[1]), idx)
        distance = acosd(dot(vec, vec′))
        if distance < 1.0
            push!(aperture, idx)
        elseif 3.0 < distance < 5.0
            push!(annulus, idx)
        end
    end
    spectrum = zeros(length(maps))
    for idx = 1:length(maps)
        map = maps[idx]
        spectrum[idx] = maximum(map[aperture]) - median(map[annulus])
        spectrum[idx] /= getpeak(psfs[idx], θ)
    end
    spectrum
end

macro perley_spectrum(args...)
    flux = 10^args[1]
    coeff = [args[2:end]...]
    quote
        PowerLaw($flux, 0, 0, 0, 1e9, $coeff)
    end
end

macro scaife_spectrum(args...)
    flux = args[1]
    coeff = [args[2:end]...]
    quote
        PowerLaw($flux, 0, 0, 0, 150e6, $coeff)
    end
end

macro baars_spectrum(args...)
    flux = 10^args[1]
    coeff = [args[2:end]...]
    quote
        PowerLaw($flux, 0, 0, 0, 1e6, $coeff)
    end
end

calibrators = Dict("3C 48"  => Direction(dir"J2000", "01h37m41.2971s", "+33d09m35.118s"),
                   "Per B"  => Direction(dir"J2000", "04h37m04.3753s", "+29d40m13.819s"),   # subtracted
                   "3C 147" => Direction(dir"J2000", "05h42m36.2646s", "+49d51m07.083s"),
                   "Lyn A"  => Direction(dir"J2000", "08h13m36.05609s", "+48d13m02.6360s"),
                   "Hya A"  => Direction(dir"J2000", "09h18m05.651s", "-12d05m43.99s"),     # subtracted
                   "Vir A"  => Direction(dir"J2000", "12h30m49.42338s", "+12d23m28.0439s"), # subtracted
                   "3C 286" => Direction(dir"J2000", "13h31m08.3s", "+30d30m33s"),
                   "3C 295" => Direction(dir"J2000", "14h11m20.467s", "+52d12m09.52s"),
                   "3C 353" => Direction(dir"J2000", "17h20m28.147s", "-00d58m47.12s"),     # subtracted
                   "3C 380" => Direction(dir"J2000", "18h29m31.72483s", "+48d44m46.9515s"),
                   "Cyg A"  => Direction(dir"J2000", "19h59m28.35663s", "+40d44m02.0970s")) # subtracted

function perley_flux_calibrators()
    spectra = Dict("3C 48"  => @perley_spectrum(1.3253, -0.7553, -0.1914, +0.0498),
                   "Per B"  => @perley_spectrum(1.8017, -0.7884, -0.1035, -0.0248, +0.0090),
                   "3C 147" => @perley_spectrum(1.4516, -0.6961, -0.2007, +0.0640, -0.0464, +0.0289),
                   "Lyn A"  => @perley_spectrum(1.2872, -0.8530, -0.1534, -0.0200, +0.0201),
                   "Hya A"  => @perley_spectrum(1.7795, -0.9176, -0.0843, -0.0139, +0.0295),
                   "Vir A"  => @perley_spectrum(2.4466, -0.8116, -0.0483),
                   "3C 286" => @perley_spectrum(1.2481, -0.4507, -0.1798, +0.0357),
                   "3C 295" => @perley_spectrum(1.4701, -0.7658, -0.2780, -0.0347, +0.0399),
                   "3C 353" => @perley_spectrum(1.8627, -0.6938, -0.0998, -0.0732),
                   "3C 380" => @perley_spectrum(1.2320, -0.7909, +0.0947, +0.0976, -0.1794, -0.1566),
                   "Cyg A"  => @perley_spectrum(3.3498, -1.0022, -0.2246, +0.0227, +0.0425))
    spectra
end

function scaife_flux_calibrators()
    spectra = Dict("3C 48"  => @scaife_spectrum(64.768, -0.387, -0.420, +0.181),
                   "3C 147" => @scaife_spectrum(66.738, -0.022, -1.012, +0.549),
                   "Lyn A"  => @scaife_spectrum(83.084, -0.699, -0.110),
                   "3C 286" => @scaife_spectrum(27.477, -0.158, +0.032, -0.180),
                   "3C 295" => @scaife_spectrum(97.763, -0.582, -0.298, +0.583, -0.363),
                   "3C 380" => @scaife_spectrum(77.352, -0.767))
    spectra
end

function baars_flux_calibrators()
    spectra = Dict("Cyg A"  => @baars_spectrum(4.695, +0.085, -0.178))
    spectra
end


getfrequencies(spws, dataset) = [getmeta(spw, dataset).channels[55] for spw in spws]

