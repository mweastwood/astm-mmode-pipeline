function elevation_plots(dataset)
    elevation_plot_cyg(dataset)
    elevation_plot_cas(dataset)
    elevation_plot_vir(dataset)
    elevation_plot_tau(dataset)
    elevation_plot_her(dataset)
end

elevation_plot_cyg(dataset) = elevation_plot(dataset, source_dictionary["Cyg A"], "Cyg A")
elevation_plot_cas(dataset) = elevation_plot(dataset, source_dictionary["Cas A"], "Cas A")
elevation_plot_vir(dataset) = elevation_plot(dataset, source_dictionary["Vir A"], "Vir A")
elevation_plot_tau(dataset) = elevation_plot(dataset, source_dictionary["Tau A"], "Tau A")
elevation_plot_her(dataset) = elevation_plot(dataset, source_dictionary["Her A"], "Her A")
elevation_plot_sun(dataset) = elevation_plot(dataset, source_dictionary["Sun"], "Sun")

function elevation_plot(dataset, direction, name)
    meta = getmeta(18, dataset)
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
    figure(); clf()
    plot(1:N, rad2deg(el), "k-")
    xlim(1, N)
    ylim(0, 90)
    for thresh in (5, 10, 15, 30, 45, 60)
        axhline(thresh)
    end
    grid("on")
    title(name)
end

