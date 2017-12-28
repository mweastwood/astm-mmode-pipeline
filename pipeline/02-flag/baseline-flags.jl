#using PyPlot

function apply_baseline_flags!(data, flags, metadata)
    y = abs.(squeeze(mean(data, 2), 2))
    b = ustrip.([norm(metadata.positions[ant1] - metadata.positions[ant2])
                 for ant1 = 1:Nant(metadata) for ant2 = ant1:Nant(metadata)])

    Nbase = length(y)
    prg = Progress(Nbase)
    for α = 1:Nbase
        if y[α] != 0
            flags.baseline_flags[α] |= flag_this_baseline(b, y, α)
        end
        next!(prg)
    end

    flags
end

function flag_this_baseline(b, y, α)
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
    flag = me .> m + 10σ

    #figure(1); clf()
    #plot(b, y, "k.")
    #axhline(m+10σ)

    flag
end

