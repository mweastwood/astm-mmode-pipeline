module Driver

using FileIO, JLD2
using ProgressMeter
using TTCal
using BPJSpec
using Dierckx
using Unitful # for ustrip
using YAML
using UnicodePlots

include("Project.jl")

struct Config
    input  :: String
    output :: String
    output_accumulated :: String
    output_flags :: String
    metadata :: String
    special_antennas :: Vector{Int}
    special_baselines :: Vector{Int}
    a_priori_antenna_flags  :: Vector{Int}
    a_priori_baseline_flags :: Vector{Tuple{Int, Int}}
    a_priori_channel_flags  :: Vector{Int}
    channel_flag_threshold     :: Int
    baseline_flag_threshold    :: Int
    integration_flag_threshold :: Int
end

function load(file)
    dict = YAML.load(open(file))
    do_the_splits(s) = (s′ = split(s, "&"); (parse(Int, s′[1]), parse(Int, s′[2])))
    a_priori_antenna_flags  = get(dict, "a-priori-antenna-flags", Int[])
    a_priori_baseline_flags = haskey(dict, "a-priori-baseline-flags") ?
                                do_the_splits.(dict["a-priori-baseline-flags"]) :
                                Tuple{Int, Int}[]
    a_priori_channel_flags  = get(dict, "a-priori-channel-flags", Int[])
    Config(dict["input"], dict["output"], dict["output-accumulated"], dict["output-flags"],
           dict["metadata"],
           get(dict, "special-antennas", Int[]),
           get(dict, "special-baselines", Int[]),
           a_priori_antenna_flags,
           a_priori_baseline_flags,
           a_priori_channel_flags,
           dict["channel-flag-threshold"],
           dict["baseline-flag-threshold"],
           dict["integration-flag-threshold"])
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
    path = Project.workspace(project)
    metadata = Project.load(project, config.metadata, "metadata")
    input  = BPJSpec.load(joinpath(path, config.input))
    output = similar(input, MultipleFiles(joinpath(path, config.output)))

    flags = Flags(metadata)

    println("Applying a-priori flags")
    a_priori_flags!(flags, config, metadata)

    if config.channel_flag_threshold > 0
        println("Flagging frequency channels using the auto-correlations")
        autos = grab_auto_correlations(input, metadata, flags)
        apply_channel_flags!(autos, flags, metadata,
                             config.channel_flag_threshold,
                             config.special_antennas)
    end

    println("Flagging auto-correlations") # now that we are done using them
    flag_autos!(flags, config, metadata)

    data = accumulate_frequency(input, metadata, flags)
    Project.save(project, config.output_accumulated, "data", data)
    #data = Project.load(project, config.output_accumulated, "data")

    if config.baseline_flag_threshold > 0
        println("Flagging baselines based on visibility amplitude as a function of baseline length")
        apply_baseline_flags!(data, flags, metadata, config.baseline_flag_threshold)
    end

    if config.integration_flag_threshold > 0
        println("Flagging integrations based on the time series of each visibility")
        apply_integration_flags!(data, flags, config.integration_flag_threshold,
                                 config.special_baselines, windowed=true)
    end

    Project.save(project, config.output_flags, "flags", flags)
    #flags = Project.load(project, config.output_flags, "flags")

    Project.set_stripe_count(project, config.output, 1)
    write_output(project, flags, input, output, metadata)
    flags
end

function write_output(project, flags, input, output, metadata)
    queue = collect(1:Ntime(metadata))
    pool  = CachingPool(workers())
    lck = ReentrantLock()
    prg = Progress(length(queue))
    increment() = (lock(lck); next!(prg); unlock(lck))

    @sync for worker in workers()
        @async while length(queue) > 0
            index = shift!(queue)
            remotecall_wait(_write_output, pool, input, output, flags, index)
            increment()
        end
    end
end

function _write_output(input, output, flags, index)
    raw_data = input[index]
    apply!(raw_data, flags, index)
    output[index] = raw_data
end

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

#function apply_to_transpose!(data, flags, frequency)
#    Npol, Nbase, Ntime = size(data)
#    for α = 1:Nbase
#        if flags.baseline_flags[α] || flags.channel_flags[α, frequency]
#            data[:, α, :] = 0
#        end
#        for time = 1:Ntime
#            if flags.integration_flags[α, time]
#                data[:, α, time] = 0
#            end
#        end
#    end
#end

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

function accumulate_frequency(visibilities, metadata, flags)
    output = zeros(Complex128, Nbase(metadata), Ntime(metadata))
    count  = zeros(       Int, Nbase(metadata), Ntime(metadata))
    prg = Progress(Ntime(metadata))
    for time = 1:Ntime(metadata)
        data = visibilities[time]
        apply!(data, flags, time)
        # TODO: this assumes xx is first and yy is last
        @views output[:, time] .+= squeeze(sum(data[  1, :, :], 1), 1)
        @views output[:, time] .+= squeeze(sum(data[end, :, :], 1), 1)
        @views count[:, time]  .+= squeeze(sum(data[  1, :, :] .!= 0, 1), 1)
        @views count[:, time]  .+= squeeze(sum(data[end, :, :] .!= 0, 1), 1)
        next!(prg)
    end
    count[count .== 0] .= 1
    output ./= count
    output
end

function grab_auto_correlations(visibilities, metadata, flags)
    output = zeros(Float64, Nfreq(metadata), Nant(metadata))
    count  = zeros(    Int, Nfreq(metadata), Nant(metadata))
    prg = Progress(Ntime(metadata))
    for time = 1:Ntime(metadata)
        data = visibilities[time]
        apply!(data, flags, time)
        α = 1
        for ant1 = 1:Nant(metadata), ant2 = ant1:Nant(metadata)
            # TODO: this assumes xx is first and yy is last
            if ant1 == ant2
                @views output[:, ant1] .+= abs.(data[  1, :, α])
                @views output[:, ant1] .+= abs.(data[end, :, α])
                @views count[:, ant1]  .+= data[  1, :, α] .!= 0
                @views count[:, ant1]  .+= data[end, :, α] .!= 0
            end
            α += 1
        end
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
        if ((ant1 in config.a_priori_antenna_flags)
                || (ant2 in config.a_priori_antenna_flags)
                || ((ant1, ant2) in config.a_priori_baseline_flags)
                || ((ant2, ant1) in config.a_priori_baseline_flags))
            flags.baseline_flags[α] = true
        end
        α += 1
    end
    for β in config.a_priori_channel_flags
        flags.channel_flags[:, β] = true
    end
    flags
end

function flag_autos!(flags, config, metadata)
    α = 1
    for ant1 = 1:Nant(metadata), ant2 = ant1:Nant(metadata)
        if ant1 == ant2
            flags.baseline_flags[α] = true
        end
        α += 1
    end
    flags
end

####################################################################################################

function apply_channel_flags!(autos, flags, metadata, threshold, special_antennas)
    for ant = 1:Nant(metadata)
        spectrum = autos[:, ant]
        if !all(spectrum .== 0)
            my_flags = threshold_flag(spectrum, threshold, windowed=true,
                                      scale=10, plot=ant in special_antennas,
                                      title=@sprintf("Antenna %d", ant),
                                      xlabel="Channel #")
            for β in find(my_flags)
                flags.channel_flags[:, β] = true
            end
        end
    end
end

####################################################################################################

function apply_baseline_flags!(data, flags, metadata, threshold)
    y = abs.(squeeze(mean(data, 2), 2))
    b = ustrip.([norm(metadata.positions[ant1] - metadata.positions[ant2])
                 for ant1 = 1:Nant(metadata) for ant2 = ant1:Nant(metadata)])

    original_y = copy(y)
    original_flags = y .== 0

    Nbase = length(y)
    for α = 1:Nbase
        flags.baseline_flags[α] |= flag_this_baseline(b, y, α, threshold)
    end

    final_flags = y .== 0
    new_flags = final_flags .& .!original_flags

    plt = scatterplot(b[.!final_flags], y[.!final_flags], width=100, name="unflagged")
    scatterplot!(plt, b[new_flags], original_y[new_flags], name="new flags")
    title!(plt, "Baseline Flags")
    xlabel!(plt, "Baseline Length / m")
    println(plt)

    flags
end

function flag_this_baseline(b, y, α, threshold)
    y[α] == 0 && return false
    me   = y[α]
    me_b = b[α]

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

    flag
end

####################################################################################################

function apply_integration_flags!(data, flags, threshold, special_baselines; windowed=false)
    Nbase, Ntime = size(data)
    for α = 1:Nbase
        time_series = data[α, :]
        if !all(time_series .== 0)
            flags.integration_flags[α, :] = threshold_flag(time_series, threshold,
                                                           windowed=windowed,
                                                           scale=10,
                                                           plot=α in special_baselines,
                                                           title=@sprintf("Baseline %d", α),
                                                           xlabel="Integration #")
        end
    end
    flags
end

####################################################################################################

function threshold_flag(data, threshold; windowed=false, scale=10,
                        plot=false, xlabel="", title="")
    x = 1:length(data)
    y = abs.(data)
    f = y .== 0

    local flags, mad
    for idx = 1:2
        knots = x[.!f][2:scale:end-1]
        spline = Spline1D(x[.!f], y[.!f], knots)
        z = spline.(x)
        deviation = abs.(y .- z)

        if idx == 1
            mad = windowed ? windowed_mad(deviation) : median(deviation)
        end

        flags = deviation .> threshold .* mad
    end

    if plot
        plt = scatterplot(x[.!flags], y[.!flags], width=100, name="unflagged")
        scatterplot!(plt, x[flags], y[flags], name="flagged")
        title!(plt, title)
        xlabel!(plt, xlabel)
        println(plt)
    end

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

