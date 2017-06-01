function flag(spw, dataset, target)
    dir = getdir(spw)
    times, data = load(joinpath(dir, "$target-$dataset-visibilities.jld"), "times", "data")
    flags = flag!(spw, data, dataset, target)
    save(joinpath(dir, "flagged-$target-$dataset-visiblities.jld"),
         "times", times, "data", data, "flags", flags, compress=true)
    save(joinpath(dir, "flagged-$target-$dataset-autos.jld"),
         "data", just_the_autos(data), "flags", just_the_auto_flags(flags), compress=true)
end

"""
    flag!(spw, data, dataset, target)

Apply a set of a priori antenna and baseline flags. Additionally look for and flag extremely
egregious integrations.

This function will modify the input `data` by zero-ing out the flagged pieces.
"""
function flag!(spw, data, dataset, target)
    _, Nbase, Ntime = size(data)
    Nant = Nbase2Nant(Nbase)
    flags = zeros(Bool, Nbase, Ntime)

    # antenna flags
    if dataset == "100hr"
        files = ["100hr.ants"]
    elseif dataset == "rainy"
        files = ["rainy.ants"]
        file = @sprintf("rainy-spw%02d.ants", spw)
        if isfile(joinpath(Common.workspace, "flags", file))
            push!(files, file)
        end
    else
        files = String[]
    end
    if length(files) != 0
        for file in files
            apply_antenna_flags!(flags, file)
        end
    else
        Lumberjack.warn("no antenna flags applied")
    end

    # baseline flags
    if dataset == "100hr"
        files = ["100hr.bl"]
    elseif dataset == "rainy"
        files = ["rainy.bl"]
        file = @sprintf("rainy-spw%02d.bl", spw)
        if isfile(joinpath(Common.workspace, "flags", file))
            push!(files, file)
        end
    else
        files = String[]
    end
    if length(files) != 0
        for file in files
            apply_baseline_flags!(flags, file)
        end
    else
        Lumberjack.warn("no baseline flags applied")
    end

    # integration flags
    do_integration_flags!(flags, data)

    # special case flags
    do_special_case_flags!(spw, dataset, target, flags)

    flags
end

function apply_antenna_flags!(flags, antennas::Vector{Int})
    Nbase = size(flags, 1)
    Nant = Nbase2Nant(Nbase)
    for ant1 in antennas, ant2 = 1:Nant
        if ant1 ≤ ant2
            α = baseline_index(ant1, ant2)
        else
            α = baseline_index(ant2, ant1)
        end
        flags[α, :] = true
    end
end

function apply_baseline_flags!(flags, baselines::Matrix{Int})
    for idx = 1:size(baselines, 1)
        ant1 = baselines[idx, 1]
        ant2 = baselines[idx, 2]
        α = baseline_index(ant1, ant2)
        flags[α, :] = true
    end
end

apply_antenna_flags!(flags, file::String) = apply_antenna_flags!(flags, read_antenna_flags(file))
apply_baseline_flags!(flags, file::String) = apply_baseline_flags!(flags, read_baseline_flags(file))

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
                end
                for ant2 = ant+1:Nant
                    α = baseline_index(ant, ant2)
                    flags[α, idx] = true
                end
            end
        end
    end

    for idx = 1:Ntime
        if votes[idx] / total[idx] > 0.05
            flags[:, idx] = true
        end
    end
end

function do_special_case_flags!(spw, dataset, target, flags)
    if dataset == "rainy"
        if spw == 12
            flags[:, 3467] = true # fireball
            flags[:, 4939] = true # fireball
        elseif spw == 16
            flags[:, 6635] = true # fireball
        end
    end
end


function read_antenna_flags(filename) :: Vector{Int}
    flags = readdlm(joinpath(Common.workspace, "flags", filename), Int)
    reshape(flags, length(flags))
end

function read_baseline_flags(filename) :: Matrix{Int}
    flags = readdlm(joinpath(Common.workspace, "flags", filename), '&', Int)
    flags
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

