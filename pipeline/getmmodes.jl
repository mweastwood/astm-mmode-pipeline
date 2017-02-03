function getmmodes(spw)
    Lumberjack.info("Calculating m-modes for spectral window $spw")
    dir = getdir(spw)
    FFTW.set_num_threads(16)

    path_to_visibilities = joinpath(dir, "visibilities.jld")
    Lumberjack.info("Loading visibilities from $path_to_visibilities")
    times, data, flags = load(path_to_visibilities, "times", "data", "flags")

    Lumberjack.info("Folding data in sidereal time")
    combined = combine_days(spw, times, data, flags)

    path_to_combined_visibilities = joinpath(dir, "visibilities")
    Lumberjack.info("Saving combined visiblities to $path_to_combined_visibilities")
    Nbase = size(combined, 1)
    Ntime = size(combined, 2)
    meta = getmeta(spw)
    β = round(Int, middle(1:Nfreq(meta)))
    ν = meta.channels[β:β]
    origin = 0.0
    visibilities = GriddedVisibilities(path_to_combined_visibilities, Nbase, Ntime, ν, origin)
    visibilities[1] = combined
    #visibilities.data[1][:] = combined
    #visibilities.weights[1][:] = 1.0

    path_to_mmodes = joinpath(dir, "mmodes")
    Lumberjack.info("Computing m-modes and saving them to $path_to_mmodes")
    mmodes = MModes(path_to_mmodes, visibilities, 1000)

    nothing
end

