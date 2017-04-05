function elevation_plot_vir(dataset)
    direction = Direction(dir"J2000", "12h30m49.42338s", "+12d23m28.0439s")
    elevation_plot(dataset, direction)
end

function elevation_plot_tau(dataset)
    direction = Direction(dir"J2000", "05h34m31.94s", "+22d00m52.2s")
    elevation_plot(dataset, direction)
end

function elevation_plot(dataset, direction)
    meta = getmeta(18)
    dir = getdir(18)
    times = load(joinpath(dir, "raw-$dataset-visibilities.jld"), "times")
    el = zeros(length(times))
    for idx = 1:length(times)
        meta.time = Epoch(epoch"UTC", times[idx]*seconds)
        frame = TTCal.reference_frame(meta)
        azel = measure(frame, direction, dir"AZEL")
        el[idx] = latitude(azel)
    end
    N = length(times)
    figure(1); clf()
    plot(1:N, rad2deg(el), "k-")
    xlim(1, N)
    ylim(0, 90)
end

