#using PyPlot

function apply_baseline_flags!(data, flags, metadata, threshold)
    y = abs.(squeeze(mean(data, 2), 2))
    b = ustrip.([norm(metadata.positions[ant1] - metadata.positions[ant2])
                 for ant1 = 1:Nant(metadata) for ant2 = ant1:Nant(metadata)])

    #figure(1); clf()
    #of = copy(f)
    #f = flags.baseline_flags
    #plot(b, y, "k.")

    Nbase = length(y)
    prg = Progress(Nbase)
    for α = 1:Nbase
        flags.baseline_flags[α] |= flag_this_baseline(b, y, α, threshold)
        next!(prg)
    end

    #plot(b[f], y[f], "r.")
    #plot(b[of], y[of], "b.")

    flags
end

function flag_this_baseline(b, y, α, threshold)
    y[α] == 0 && return false
    me = y[α]

    # select baselines within 10% of this current baseline
    w = b[α]*0.9 .< b .< b[α]*1.1
    y = y[w]
    b = b[w]

    # remove already flagged baselines from consideration
    f = y .== 0
    y = y[.!f]
    b = b[.!f]

    m = median(y)
    δ = y .- m
    σ = median(abs.(δ))
    flag = me .> m + threshold*σ

    #figure(1); clf()
    #plot(b, y, "k.")
    #axhline(m+10σ)

    flag
end

