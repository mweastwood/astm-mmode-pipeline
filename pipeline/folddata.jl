function folddata(spw; input="visibilities", output="visibilities")
    dir = getdir(spw)
    input = joinpath(dir, input*".jld")
    output = joinpath(dir, output)
    Lumberjack.info("Loading the data from $input")
    times, data, flags = load(input, "times", "data", "flags")
    Lumberjack.info("Folding the data from spectral window $spw")
    combined = combine_days(spw, times, data, flags)
    Lumberjack.info("Saving the folded data to $output")
    Nbase = size(combined, 1)
    Ntime = size(combined, 2)
    meta = getmeta(spw)
    β = round(Int, middle(1:Nfreq(meta)))
    ν = meta.channels[β:β]
    origin = 0.0
    visibilities = GriddedVisibilities(output, Nbase, Ntime, ν, origin)
    visibilities[1] = combined
end

function combine_days(spw, times, data, flags)
    Ntime1 = 6628          # number of integrations per sidereal day
    Ntime2 = size(data, 2) # number of integrations in the data
    Nbase = size(data, 1)  # number of baselines
    # flag the auto correlations
    for ant = 1:256
        α = baseline_index(ant, ant)
        flags[α, :] = true
    end

    if spw == 18
        integration_flags = load(joinpath(getdir(spw), "integration-flags.jld"), "flags")
        flags[:, integration_flags] = true
        #flags[:, 3732:3750] = true
        #flags[:, 3803:3807] = true
        #flags[:, 3816:3828] = true
        #flags[:, 3926] = true
    end

    if any(isnan(data))
        @show unique(j)
        Lumberjack.error("NaNs in the original data set")
    end

    #day1 = 1:6628
    #day2 = 6629:13256
    #day3 = 13257:19884
    #day4 = 19885:26262
    #flags[:, day1] = true
    #flags[:, day2] = true
    #flags[:, day3] = true
    #flags[:, day4] = true
    #range = 21964:22064
    #flags[:, 1:range[1]-1] = true
    #flags[:, range[end]+1:end] = true
    # fold the data in sidereal time
    combined = zeros(Complex128, Nbase, Ntime1)
    for idx = 1:Ntime1
        integrations = idx:Ntime1:Ntime2 # integrations measuring the same sidereal time
        data_list = [view(data,  :, integration) for integration in integrations]
        flag_list = [view(flags, :, integration) for integration in integrations]
        averaged = robust_mean(data_list, flag_list)
        combined[:,idx] = averaged
    end
    if any(isnan(combined))
        Lumberjack.error("NaNs in the combined data set")
    elseif all(combined .== 0)
        Lumberjack.error("The combined data set is entirely zero")
    end
    combined
end

function robust_mean(data_list, flag_list)
    N = length(data_list)
    M = length(data_list[1])

    entirely_flagged = Bool[all(flag_list[idx]) || all(data_list[idx] .== 0) for idx = 1:N]
    data_list = data_list[!entirely_flagged]
    flag_list = flag_list[!entirely_flagged]

    while true
        N = length(data_list)
        N > 1 || break
        selection = fill(true, N)
        norms = zeros(N)
        for idx = 1:N
            selection[:] = true
            selection[idx] = false
            norms[idx] = compute_norm(data_list[selection], flag_list[selection])
        end
        # discard an integration if the norm is much lower while excluding it
        maxnorm = maximum(norms)
        minnorm = minimum(norms)
        if minnorm/maxnorm < 0.5
            idx = indmin(norms)
            selection[:] = true
            selection[idx] = false
            data_list = data_list[selection]
            flag_list = flag_list[selection]
        else
            break
        end
    end
    if N == 0
        return zeros(Complex128, M)
    else
        return compute_mean(data_list, flag_list)
    end
end

function compute_norm(data_list, flag_list)
    N = length(data_list[1])
    output = 0.0
    for (data, flags) in zip(data_list, flag_list)
        for idx = 1:N
            output += ifelse(flags[idx], 0.0, abs2(data[idx]))
        end
    end
    output
end

function compute_mean(data_list, flag_list)
    N = length(data_list[1])
    output = zeros(Complex128, N)
    for (data, flags) in zip(data_list, flag_list)
        for idx = 1:N
            output[idx] += ifelse(flags[idx], 0.0, data[idx])
        end
    end
    output
end

