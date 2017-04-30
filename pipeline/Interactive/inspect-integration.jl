function inspect_integration(spw, dataset, target, integration)
    dir = getdir(spw)
    times, data, flags = load(joinpath(dir, "$target-$dataset-visibilities.jld"),
                              "times", "data", "flags");
    inspect_integration(spw, times, data, flags, dataset, target, integration)
end

function inspect_integration(spw, times, data, flags, dataset, target, integration)
    mytime = times[integration]
    mydata = data[:, :, integration]
    myflags = flags[:, integration]

    # Get the original
    println("\n=== original ===")
    title = @sprintf("%05d-step02", integration)*"-$target-$dataset"
    inspect_do_the_work(spw, dataset, mytime, mydata, myflags, title, true, true)

    # Turn off all source removal
    println("\n=== no source removal ===")
    title = @sprintf("%05d-step00", integration)*"-$target-$dataset"
    inspect_do_the_work(spw, dataset, mytime, mydata, myflags, title, false, false)

    # No subtraction
    println("\n=== no subtraction ===")
    title = @sprintf("%05d-step01", integration)*"-$target-$dataset"
    inspect_do_the_work(spw, dataset, mytime, mydata, myflags, title, true, false)
end

function inspect_do_the_work(spw, dataset, time, data, flags, title, dopeeling, dosubtraction)
    data = copy(data)
    flags = copy(flags)

    dir = getdir(spw)
    meta = getmeta(spw, dataset)
    meta.channels = meta.channels[55:55]
    sources = readsources(joinpath(dirname(@__FILE__), "..", "..", "workspace", "source-lists",
                                   "getdata-sources.json"))

    Calibration.peel_do_the_work(time, data, flags, spw, dir, meta, sources,
                                 true, dopeeling, dosubtraction)
    image(spw, data, flags, 1:1, joinpath(dir, "tmp", title))
end

