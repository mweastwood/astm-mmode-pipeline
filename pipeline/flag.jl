function flag(spw, target="raw-visibilities")
    dir = getdir(spw)
    times, data = load(joinpath(dir, target*".jld"), "times", "data")
    flags = flag!(spw, data, target)
    save(joinpath(dir, "flagged-$target.jld"),
         "times", times, "data", data, "flags", flags, compress=true)
end

"""
    flag!(spw, data, target)

Apply a set of a priori antenna and baseline flags. Additionally look for and flag extremely
egregious integrations.

This function will modify the input `data` by zero-ing out the flagged pieces.
"""
function flag!(spw, data, target)
    _, Nbase, Ntime = size(data)
    Nant = Nbase2Nant(Nbase)
    flags = zeros(Bool, Nbase, Ntime)

    # antenna flags
    if target == "raw-visibilities"
        files = ["coreflags_arxpickup.ants", "coreflags_gregg.ants", "coreflags_nosignal.ants",
                 "expansionflags.ants", "ledaants.ants", "flagsRyan.ants", "flagsMarin.ants"]
    elseif target == "raw-rainy-visibilities"
        files = ["rainy.ants"]
    else
        files = String[]
    end
    if length(files) > 0
        antennas = sort!(vcat(collect(read_antenna_flags(file) for file in files)...)) :: Vector{Int}
        if target == "raw-visibilities" && spw == 18
            antennas = [antennas; 59; 60; 61; 62; 63; 64] # see email sent 2017/02/07 12:18am
        elseif target == "raw-rainy-visibilities" && spw == 18
            antennas = [antennas; 15; 59; 64; 68; 69; 70; 123; 167; 168; 184; 186; 189; 191]
        end
        antennas = unique(antennas)
        for ant1 in antennas, ant2 = 1:Nant
            if ant1 ≤ ant2
                α = baseline_index(ant1, ant2)
            else
                α = baseline_index(ant2, ant1)
            end
            flags[α, :] = true
            data[:, α, :] = 0
        end
    end

    # baseline flags
    if target == "raw-visibilities"
        files = ["flagsRyan_adjacent.bl", "flagsRyan_score.bl", "flagsMarin.bl"]
    elseif target == "raw-rainy-visibilities"
        files = ["rainy.bl"]
    else
        files = ["flagsRyan_adjacent.bl"]
    end
    if length(files) > 0
        baselines = vcat(collect(read_baseline_flags(file) for file in files)...) :: Matrix{Int}
        for idx = 1:size(baselines, 1)
            ant1 = baselines[idx, 1]
            ant2 = baselines[idx, 2]
            α = baseline_index(ant1, ant2)
            flags[α, :] = true
            data[:, α, :] = 0
        end
    end

    # integration flags
    do_integration_flags!(flags, data)

    flags
end

function do_integration_flags!(flags, data)
    _, Nbase, Ntime = size(data)
    Nant = Nbase2Nant(Nbase)

    autos = just_the_autos(data)
    auto_flags = just_the_auto_flags(flags)

    votes = zeros(Int, Ntime)
    total = zeros(Int, Ntime)
    for ant = 1:Nant, pol = 1:2
        myautos = autos[pol, ant, :]
        myflags = auto_flags[ant, :]
        all(myflags) && continue

        # Pass a median filter over the time series in order to smooth out any RFI spikes.
        width = 500
        median_filtered = zeros(Ntime)
        for t = 1:Ntime
            boxcar = -width÷2:width÷2
            boxcar = boxcar + t
            boxcar = max(1, boxcar[1]):min(Ntime, boxcar[end])
            median_filtered[t] = median(myautos[boxcar])
        end
        galaxy_subtracted = myautos - median_filtered

        # Use the median-absolute-deviation to test for bursts of RFI.
        mad = median(abs(galaxy_subtracted))
        cutoff = 5mad
        rfi = abs(galaxy_subtracted) .> cutoff
        votes[rfi] += 1
        total[:] += 1

        for idx = 1:Ntime
            if rfi[idx]
                for ant1 = 1:ant
                    α = baseline_index(ant1, ant)
                    flags[α, idx] = true
                    data[:, α, idx] = 0
                end
                for ant2 = ant+1:Nant
                    α = baseline_index(ant, ant2)
                    flags[α, idx] = true
                    data[:, α, idx] = 0
                end
            end
        end
    end

    for idx = 1:Ntime
        if votes[idx] / total[idx] > 0.05
            flags[:, idx] = true
            data[:, :, idx] = 0
        end
    end
end

function read_antenna_flags(filename)
    flags = readcsv(joinpath(workspace, "flags", filename), Int) + 1
    reshape(flags, length(flags))
end

function read_baseline_flags(filename)
    flags = readdlm(joinpath(workspace, "flags", filename), '&', Int) + 1
    flags
end

function read_channel_flags(filename, spw)
    flags = readdlm(joinpath(workspace, "flags", filename), ':', Int)
    keep = flags[:,1] .== spw
    flags[keep, 2] + 1
end

"""
    just_the_autos(data)

Returns a copy of the `data` that contains only the auto-correlations.
"""
function just_the_autos(data)
    _, Nbase, Ntime = size(data)
    Nant = Nbase2Nant(Nbase)
    idx = [baseline_index(ant, ant) for ant = 1:Nant]
    real(data[:, idx, :])
end

"""
    just_the_auto_flags(flags)

Returns a copy of `flags` that contains only the auto-correlation flags.
"""
function just_the_auto_flags(flags)
    Nbase, Ntime = size(flags)
    Nant = Nbase2Nant(Nbase)
    idx = [baseline_index(ant, ant) for ant = 1:Nant]
    flags[idx, :]
end

