function verify_lcurve(spw)
    dir = getdir(spw)
    trials, regnorm, lsnorm = load(joinpath(dir, "lcurve.jld"), "trials", "regnorm", "lsnorm")
    regnorm /= 10000
    lsnorm /= 10000

    function do_annotation(idx, x, y)
        annotate(@sprintf("ε=%g", trials[idx]), xy=(regnorm[idx], lsnorm[idx]),
                 fontsize=12)
    end

    #figure(1); clf()
    #gca()[:tick_params](axis="both", which="major", labelsize=16)
    #plot(regnorm, lsnorm, "k-")
    #for idx = 1:50:length(trials)
    #    do_annotation(idx, 10, 10)
    #end
    #xlabel(L"\Vert a \Vert" * " (arbitrary units)", fontsize=16)
    #ylabel(L"\Vert v - Ba \Vert" * " (arbitrary units)", fontsize=16)
    #title(@sprintf("spw%02d", spw), fontsize=16)
    #tight_layout()

    tolerance = 0.01
    min_lsnorm = minimum(lsnorm)
    idx = findfirst(lsnorm .< (1+tolerance)*min_lsnorm)
    trials[idx]
end

