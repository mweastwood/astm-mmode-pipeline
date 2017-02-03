function divide_and_image(spw, range)
    times, data, flags = load("/dev/shm/mweastwood/visibilities.jld", "times", "data", "flags")
    divide_and_image(spw, range, output, times, data, flags)
end

function divide_and_image(spw, range, times, data, flags)
    output = @sprintf("%05d-%05d", range[1], range[end])
    dir = getdir(spw)
    meta = getmeta(spw)
    meta.channels = meta.channels[55:55]
    meta.phase_center = Direction(dir"AZEL", 0degrees, 90degrees)
    @time ms, path = create_template_ms(spw, joinpath(dir, "tmp", output*".ms"))

    visibilities = Visibilities(Nbase(meta), 109)
    visibilities.flags[:] = true
    visibilities.flags[:, 55:55] = flags[:, 1]
    center = PointSource("Cas A", Direction(dir"J2000", "23h23m24s", "+58d48m54s"),
                         PowerLaw(1, 0, 0, 0, 1e6, [0.0]))

    integration_flags = load(joinpath(getdir(spw), "integration-flags.jld"), "flags")

    p = Progress(length(range))
    for idx in range
        if !integration_flags[idx]
            mydata = view(data, :, idx)
            myflags = view(flags, :, idx)
            meta.time = Epoch(epoch"UTC", times[idx]*seconds)
            model = genvis(meta, [center])
            for α = 1:Nbase(meta)
                if !myflags[α]
                    A = mydata[α]
                    visibilities.data[α,55] += JonesMatrix(A, 0, 0, A) / model.data[α,1]
                end
            end
        end
        next!(p)
    end

    @time TTCal.write(ms, "DATA", visibilities)
    finalize(ms)
    @time wsclean(path)
end

