module Driver

using FileIO, JLD2
using ProgressMeter
using TTCal
using Dierckx
using Unitful # for ustrip
using YAML
#using PyPlot

include("Project.jl")

struct Config
    input  :: String
    output :: String
    a_priori_antenna_flags  :: Vector{Int}
    a_priori_baseline_flags :: Vector{Tuple{Int, Int}}
    baseline_flag_threshold    :: Int
    integration_flag_threshold :: Int
    integration_variance_flag_threshold :: Int
end

function load(file)
    dict = YAML.load(open(file))
    do_the_splits(s) = (s′ = split(s, "&"); (parse(Int, s′[1]), parse(Int, s′[2])))
    a_priori_antenna_flags  = get(dict, "a-priori-antenna-flags", Int[])
    a_priori_baseline_flags = haskey(dict, "a-priori-baseline-flags") ?
                                do_the_splits.(dict["a-priori-baseline-flags"]) :
                                Tuple{Int, Int}[]
    Config(dict["input"], dict["output"], a_priori_antenna_flags, a_priori_baseline_flags,
           dict["baseline-flag-threshold"], dict["integration-flag-threshold"],
           dict["integration-variance-flag-threshold"])
end

struct Flags
    baseline_flags    :: Vector{Bool}
    integration_flags :: Matrix{Bool} # Nbase × Ntime
    channel_flags     :: Matrix{Bool} # Nbase × Nfreq
end

function Flags(metadata)
    Flags(fill(false, Nbase(metadata)),
          fill(false, Nbase(metadata), Ntime(metadata)),
          fill(false, Nbase(metadata), Nfreq(metadata)))
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    flag(project, config)
    Project.touch(project, config.output)
end

function flag(project, config)
    local flags
    jldopen(joinpath(Project.workspace(project), config.input*".jld2"), "r") do file
        metadata = file["metadata"]
        flags = Flags(metadata)
        a_priori_flags!(flags, config, metadata)

        data = accumulate_frequency(file, metadata, flags)
        if config.baseline_flag_threshold > 0
            apply_baseline_flags!(data, flags, metadata, config.baseline_flag_threshold)
        end
        if config.integration_flag_threshold > 0
            apply_integration_flags!(data, flags, config.integration_flag_threshold, windowed=true)
        end

        if config.integration_variance_flag_threshold > 0
            data = accumulate_frequency(file, metadata, flags)
            apply_integration_flags!(data, flags, config.integration_variance_flag_threshold,
                                     windowed=false)
        end
    end
    output(project, flags, config.input, config.output)
    flags
end

function output(project, flags, input, output)
    path = Project.workspace(project)
    jldopen(joinpath(path, input*".jld2"), "r") do input_file
        metadata = input_file["metadata"]
        jldopen(joinpath(path, output*".jld2"), "w") do output_file
            prg = Progress(Ntime(metadata))
            for time = 1:Ntime(metadata)
                raw_data = input_file[o6d(time)]
                apply!(raw_data, flags, time)
                output_file[o6d(time)] = raw_data
                next!(prg)
            end
            output_file["metadata"] = metadata
            output_file["flags"] = flags
        end
    end
end

o6d(i) = @sprintf("%06d", i)

####################################################################################################

function apply!(data, flags, time)
    Npol, Nfreq, Nbase = size(data)
    for α = 1:Nbase
        if flags.baseline_flags[α] || flags.integration_flags[α, time]
            data[:, :, α] = 0
        end
        for frequency = 1:Nfreq
            if flags.channel_flags[α, frequency]
                data[:, frequency, α] = 0
            end
        end
    end
end

function apply_to_transpose!(data, flags, frequency)
    Npol, Nbase, Ntime = size(data)
    for α = 1:Nbase
        if flags.baseline_flags[α] || flags.channel_flags[α, frequency]
            data[:, α, :] = 0
        end
        for time = 1:Ntime
            if flags.integration_flags[α, time]
                data[:, α, time] = 0
            end
        end
    end
end

####################################################################################################

#function accumulate_time(file, metadata, flags)
#    output = zeros(Complex128, Nbase(metadata), Nfreq(metadata))
#    count  = zeros(       Int, Nbase(metadata), Nfreq(metadata))
#    prg = Progress(Nfreq(metadata))
#    for frequency = 1:Nfreq(metadata)
#        data = file[o6d(frequency)]
#        apply_to_transpose!(data, flags, frequency)
#        @views output[:, frequency] .+= squeeze(sum(data[1, :, :], 2), 2)
#        @views output[:, frequency] .+= squeeze(sum(data[2, :, :], 2), 2)
#        @views count[:, frequency]  .+= squeeze(sum(data[1, :, :] .!= 0, 2), 2)
#        @views count[:, frequency]  .+= squeeze(sum(data[2, :, :] .!= 0, 2), 2)
#        next!(prg)
#    end
#    count[count .== 0] .= 1
#    output ./= count
#    output
#end

function accumulate_frequency(file, metadata, flags)
    output = zeros(Complex128, Nbase(metadata), Ntime(metadata))
    count  = zeros(       Int, Nbase(metadata), Ntime(metadata))
    prg = Progress(Ntime(metadata))
    for time = 1:Ntime(metadata)
        data = file[o6d(time)]
        apply!(data, flags, time)
        @views output[:, time] .+= squeeze(sum(data[1, :, :], 1), 1)
        @views output[:, time] .+= squeeze(sum(data[2, :, :], 1), 1)
        @views count[:, time]  .+= squeeze(sum(data[1, :, :] .!= 0, 1), 1)
        @views count[:, time]  .+= squeeze(sum(data[2, :, :] .!= 0, 1), 1)
        next!(prg)
    end
    count[count .== 0] .= 1
    output ./= count
    output
end

function accumulate_frequency_variance(file, metadata, flags)
    output = zeros(Complex128, Nbase(metadata), Ntime(metadata))
    count  = zeros(       Int, Nbase(metadata), Ntime(metadata))
    prg = Progress(Ntime(metadata))
    for time = 1:Ntime(metadata)
        data = file[o6d(time)]
        apply!(data, flags, time)
        @views output[:, time] .+= squeeze(std(data, (1, 2)), (1, 2))
        @views count[:, time]  .+= squeeze(sum(data .!= 0, (1, 2)), (1, 2))
        next!(prg)
    end
    count[count .== 0] .= 1
    output ./= count
    output
end

####################################################################################################

function a_priori_flags!(flags, config, metadata)
    α = 1
    for ant1 = 1:Nant(metadata), ant2 = ant1:Nant(metadata)
        if ((ant1 == ant2) || (ant1 in config.a_priori_antenna_flags)
                           || (ant2 in config.a_priori_antenna_flags)
                           || ((ant1, ant2) in config.a_priori_baseline_flags)
                           || ((ant2, ant1) in config.a_priori_baseline_flags))
            flags.baseline_flags[α] = true
        end
        α += 1
    end
    flags
end

####################################################################################################

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

####################################################################################################

function apply_integration_flags!(data, flags, threshold; windowed=false)
    Nbase, Ntime = size(data)
    # Problem integrations to check by hand:
    # * 30741 - the longest baseline
    # * 19520 - problematic baseline at integration 763
    # * 314 - erroneously flagged at integration 2000 (when using unwindowed median)
    # * 4228
    prg = Progress(Nbase)
    for α = 1:Nbase
        time_series = data[α, :]
        if !all(time_series .== 0)
            flags.integration_flags[α, :] = threshold_flag(time_series, threshold, windowed)
        end
        next!(prg)
    end
    flags
end

function threshold_flag(data, threshold, windowed)
    x = 1:length(data)
    y = abs.(data)
    f = y .== 0
    knots = x[.!f][2:10:end-1]
    spline = Spline1D(x[.!f], y[.!f], knots)
    z = spline.(x)
    deviation = abs.(y .- z)
    if windowed
        mad = windowed_mad(deviation)
    else
        mad = median(deviation)
    end
    flags = deviation .> threshold .* mad

    # iterate on the spline once
    f .|= flags
    knots = x[.!f][2:10:end-1]
    spline = Spline1D(x[.!f], y[.!f], knots)
    z = spline.(x)
    deviation = abs.(y .- z)
    flags = deviation .> threshold .* mad

    #figure(1); clf()
    #plot(x, y, "k-")
    #plot(x, z, "b-")
    #plot(x, z+threshold*mad, "r-")

    flags
end

function windowed_mad(deviation)
    # the system temperature varies with time, computing the median-absolute-deviation within a
    # window allows our threshold to also vary with time
    N = length(deviation)
    output = similar(deviation)
    for idx = 1:N
        window = max(1, idx-100):min(N, idx+100)
        output[idx] = do_the_thing(deviation, window)
    end
    output
end

function do_the_thing(deviation, window)
    δ = view(deviation, window)
    median(δ)
end

####################################################################################################

end

