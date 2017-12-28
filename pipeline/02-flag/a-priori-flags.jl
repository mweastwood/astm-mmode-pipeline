function a_priori_flags!(flags, spw, name)
    antenna_flags  =  read_antenna_flags(spw, name)
    baseline_flags = read_baseline_flags(spw, name)
    Nbase = length(flags.baseline_flags)
    Nant  = Nbase2Nant(Nbase)
    α = 1
    for ant1 = 1:Nant, ant2 = ant1:Nant
        if ((ant1 == ant2) || (ant1 in antenna_flags)
                           || (ant2 in antenna_flags)
                           || ((ant1, ant2) in baseline_flags)
                           || ((ant2, ant1) in baseline_flags))
            flags.baseline_flags[α] = true
        end
        α += 1
    end
    flags
end

# a priori antenna flags

function read_antenna_flags(spw, name)
    flags = Int[]
    directory = joinpath(Common.workspace, "flags")
    for file in (@sprintf("%s.ants", name),
                 @sprintf("%s-spw%02d.ants", name, spw))
        isfile(joinpath(directory, file)) || continue
        antennas = read_antenna_flags(joinpath(directory, file))
        for ant in antennas
            push!(flags, ant)
        end
    end
    flags
end

function read_antenna_flags(path) :: Vector{Int}
    flags = readdlm(path, Int)
    reshape(flags, length(flags))
end

# a priori baseline flags

function read_baseline_flags(spw, name)
    flags = Tuple{Int, Int}[]
    directory = joinpath(Common.workspace, "flags")
    for file in (@sprintf("%s.bl", name),
                 @sprintf("%s-spw%02d.bl", name, spw))
        isfile(joinpath(directory, file)) || continue
        baselines = read_baseline_flags(joinpath(directory, file))
        for idx = 1:size(baselines, 1)
            ant1 = baselines[idx, 1]
            ant2 = baselines[idx, 2]
            push!(flags, (ant1, ant2))
        end
    end
    flags
end

function read_baseline_flags(path) :: Matrix{Int}
    flags = readdlm(path, '&', Int)
    flags
end

