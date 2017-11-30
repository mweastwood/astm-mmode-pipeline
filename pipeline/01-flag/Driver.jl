module Driver

using JLD2
using ProgressMeter

include("../lib/Common.jl");  using .Common

function flag(spw, dataset)
    antenna_flags  = flag_antennas(spw, dataset)
    baseline_flags = flag_baselines(spw, dataset)
    reconcile_antenna_baseline_flags!(antenna_flags, baseline_flags)
    path = getdir(spw, dataset)
    jldopen(joinpath(path, "raw-visibilities.jld2"), "a+") do file
        file["baseline-flags"] = baseline_flags
    end
end

function reconcile_antenna_baseline_flags!(antenna_flags, baseline_flags)
    Nant = length(antenna_flags)
    for ant1 = 1:Nant, ant2 = ant1:Nant
        if antenna_flags[ant1] || antenna_flags[ant2]
            α = baseline_index(ant1, ant2)
            baseline_flags[α] = true
        end
    end
    baseline_flags
end

# Antenna flags

function flag_antennas(spw, dataset)
    flags = fill(false, 256)
    directory = joinpath(Common.workspace, "flags")
    for file in (@sprintf("%s.ants", dataset),
                 @sprintf("%s-spw%02d.ants", dataset, spw))
        isfile(joinpath(directory, file)) || continue
        antennas = read_antenna_flags(joinpath(directory, file))
        for ant in antennas
            flags[ant] = true
        end
    end
    flags
end

function read_antenna_flags(path) :: Vector{Int}
    flags = readdlm(path, Int)
    reshape(flags, length(flags))
end

# Baseline flags

function flag_baselines(spw, dataset)
    flags = fill(false, Nant2Nbase(256))
    directory = joinpath(Common.workspace, "flags")
    for file in (@sprintf("%s.bl", dataset),
                 @sprintf("%s-spw%02d.bl", dataset, spw))
        isfile(joinpath(directory, file)) || continue
        baselines = read_baseline_flags(joinpath(directory, file))
        for idx = 1:size(baselines, 1)
            ant1 = baselines[idx, 1]
            ant2 = baselines[idx, 2]
            α = baseline_index(ant1, ant2)
            flags[α, :] = true
        end
    end
    flags
end

function read_baseline_flags(path) :: Matrix{Int}
    flags = readdlm(path, '&', Int)
    flags
end

# Channel flags

#function flag_channels(spw, baselines)
#    jldopen(joinpath(path, "raw-visibilities.jld2"), "r") do file
#        times = file["times"]
#        for integration = 1:length(times)
#            objectname = @sprintf("%06d", integration)
#            flag_channels(file[objectname])
#        end
#    end
#end
#
#function flag_channels(data)
#end

# Integration flags

#function flag_integrations(spw, baselines)
#end

end

