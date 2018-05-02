module Driver

using FileIO, JLD2
using ProgressMeter
using TTCal
using BPJSpec
using Dierckx
using Unitful # for ustrip
using YAML

include("Project.jl")

struct Config
    input            :: String
    input_transposed :: String
    output           :: String
    output_flags     :: String
    metadata         :: String
    a_priori_antenna_flags     :: Vector{Int}
    a_priori_baseline_flags    :: Vector{Tuple{Int, Int}}
    a_priori_channel_flags     :: Vector{Int}
    channel_flag_threshold     :: Float64
    integration_flag_threshold :: Float64
end

function load(file)
    dict = YAML.load(open(file))

    do_the_splits(s) = (s′ = split(s, "&"); (parse(Int, s′[1]), parse(Int, s′[2])))
    a_priori_antenna_flags  = get(dict, "a-priori-antenna-flags", Int[])
    a_priori_baseline_flags = haskey(dict, "a-priori-baseline-flags") ?
                                do_the_splits.(dict["a-priori-baseline-flags"]) :
                                Tuple{Int, Int}[]
    a_priori_channel_flags  = get(dict, "a-priori-channel-flags", Int[])

    Config(dict["input"],
           dict["input-transposed"],
           dict["output"],
           dict["output-flags"],
           dict["metadata"],
           a_priori_antenna_flags,
           a_priori_baseline_flags,
           a_priori_channel_flags,
           get(dict, "channel-flag-threshold", 0.0),
           get(dict, "integration-flag-threshold", 0.0))
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
    path     = Project.workspace(project)
    metadata = Project.load(project, config.metadata, "metadata")
    visibilities            = BPJSpec.load(joinpath(path, config.input))
    transposed_visibilities = BPJSpec.load(joinpath(path, config.input_transposed))
    output = similar(visibilities, MultipleFiles(joinpath(path, config.output)))

    flags = Flags(metadata)

    println("Applying a-priori flags")
    @time a_priori_flags!(flags, config, metadata)

    println("Flagging auto-correlations")
    @time flag_autos!(flags, config, metadata)

    if config.channel_flag_threshold > 0
        println("Flagging frequency channels that have constant offsets to the visibilities")
        @time constant_offset_flags!(flags, transposed_visibilities, metadata,
                                     config.channel_flag_threshold)
    end

    if config.integration_flag_threshold > 0
        println("Flagging events that are impulsive in time")
        @time impulsive_event_flags!(flags, visibilities, metadata,
                                     config.integration_flag_threshold)
    end

    Project.save(project, config.output_flags, "flags", flags)
    #flags = Project.load(project, config.output_flags, "flags")

    Project.set_stripe_count(project, config.output, 1)
    write_output(project, flags, visibilities, output, metadata)
    flags
end

function write_output(project, flags, input, output, metadata)
    queue = collect(1:Ntime(metadata))
    pool  = CachingPool(workers())
    lck = ReentrantLock()
    prg = Progress(length(queue))
    increment() = (lock(lck); next!(prg); unlock(lck))

    function _write(index)
        raw_data = input[index]
        apply!(raw_data, flags, index)
        output[index] = raw_data
    end

    @sync for worker in workers()
        @async while length(queue) > 0
            index = shift!(queue)
            remotecall_wait(_write, pool, index)
            increment()
        end
    end
end

"Zero out all flagged visibilities in an array with dimensions Npol × Nfreq × Nbase"
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
    data
end

"Zero out all flagged visibilities in an array with dimensions Nbase × Ntime"
function apply_to_transpose!(data, flags, frequency)
    Nbase, Ntime = size(data)
    for α = 1:Nbase
        if flags.baseline_flags[α] || flags.channel_flags[α, frequency]
            data[α, :] = 0
        end
        for time = 1:Ntime
            if flags.integration_flags[α, time]
                data[α, time] = 0
            end
        end
    end
    data
end

"Apply a pre-existing list of flags."
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

"Flag all of the auto-correlations."
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

baseline_lengths(metadata) = ustrip.([norm(metadata.positions[ant1] - metadata.positions[ant2])
                                     for ant1 = 1:Nant(metadata) for ant2 = ant1:Nant(metadata)])

"""
The goal here is to difference in frequency (canceling out the sky emission), and then look for
baselines that don't seem to be averaging down to zero over time. This will pick out common-mode
pickup and persistent narrow-band RFI.

More explicitly, we are looking for baselines that are anomalous in the ratio of the time-smeared
visibilities to the measured rms on the given baseline. Normalizing by the baseline rms helps
mitigate sensitivity to gain variations (we might not have gain calibrated yet).
"""
function constant_offset_flags!(flags, transposed_visibilities, metadata, threshold)
    lengths = baseline_lengths(metadata)
    load(β) = apply_to_transpose!(transposed_visibilities[β], flags, β)

    prg = Progress(Nfreq(metadata) - 2)
    range = 1:3
    V1 = load(1)
    V2 = load(2)
    V3 = load(3)
    _constant_offset_flags!(flags, V1, V2, V3, metadata, threshold, range, lengths)
    next!(prg)

    while last(range) < Nfreq(metadata)
        range += 1
        V1 = V2
        V2 = V3
        V3 = load(last(range))
        _constant_offset_flags!(flags, V1, V2, V3, metadata, threshold, range, lengths)
        next!(prg)
    end

    flags
end

function _constant_offset_flags!(flags, V1, V2, V3, metadata, threshold, range, lengths)
    Δ = 2 .* V2 .- V1 .- V3
    ratio = abs.(avg(Δ, 2)) ./ rms(Δ, 2)
    for α in find_unusual_baselines(lengths, ratio, threshold)
        flags.channel_flags[α, range] = true
    end
end

"""
This time, we will difference in time to cancel out the sky emission while leaving impulsive RFI
events. The amplitude of residual sky emission will generally vary smoothly with frequency, so
comparing the rms amplitude to the mean amplitude will help to pick out bad data in a way that is
insensitive to gain variations in the data.
"""
function impulsive_event_flags!(flags, visibilities, metadata, threshold)
    lengths = baseline_lengths(metadata)
    load(β) = (V = apply!(visibilities[idx], flags, idx); V[1, :, :] + V[2, :, :])

    prg = Progress(Ntime(metadata) - 2)
    range = 1:3
    V1 = load(1)
    V2 = load(2)
    V3 = load(3)
    _impulsive_event_flags!(flags, V1, V2, V3, metadata, threshold, range, lengths)
    next!(prg)

    while last(range) < Ntime(metadata)
        range += 1
        V1 = V2
        V2 = V3
        V3 = load(last(range))
        _impulsive_event_flags!(flags, V1, V2, V3, metadata, threshold, range, lengths)
        next!(prg)
    end

    flags
end

function _impulsive_event_flags!(flags, V1, V2, V3, metadata, threshold, range, lengths)
    Δ = 2 .* V2 .- V1 .- V3
    ratio = rms(Δ, 1) ./ avg(abs.(Δ), 1)
    for α in find_unusual_baselines(lengths, ratio, threshold)
        flags.channel_flags[α, range] = true
    end
end

"Get a list of all unusual baselines given the data for baselines of similar lengths."
function find_unusual_baselines(lengths, data, threshold)
    Nbase = length(data)

    # baselines shorter than 250 m are treated separately from baselines longer than 250 m, this
    # seems to be a natural division of the baselines
    cut = 250
    selection1 = lengths .> cut
    selection2 = lengths .≤ cut

    function measure_mad(selection)
        x = data[selection]
        x = x[x .!= 0]
        x = x[.!isnan.(x)]
        if length(x) > 0
            return mad(x)
        else
            return 0.0
        end
    end

    σ1 = measure_mad(selection1)
    σ2 = measure_mad(selection2)

    function sigma(α)
        lengths[α] > cut ? σ1 : σ2
    end

    find(α -> is_this_baseline_unusual(data[α], threshold*sigma(α)), 1:Nbase)
end

function is_this_baseline_unusual(value, cutoff)
    value == 0   && return false # already flagged
    isnan(value) && return false # already flagged
    value > cutoff
end

"A general purpose function for finding outliers to a curve after fitting with a spline."
function threshold_flag(data, reduction, threshold; window_size=0, scale=10, iterations=2)
    x = 1:length(data)
    y = abs.(data)
    flags = y .== 0
    original_flags = copy(flags)

    for iteration = 1:iterations
        unflagged_x = x[.!flags]
        unflagged_y = y[.!flags]
        knots  = unflagged_x[2:scale:end-1]
        spline = Spline1D(unflagged_x, unflagged_y, knots)
        deviation = y .- spline.(x)

        if window_size != 0
            σ = windowed(reduction, deviation, window_size)
        else
            σ = reduction(deviation)
        end
        new_flags = deviation .> thresholde .* σ
        flags     = new_flags .| original_flags
    end

    flags
end

function windowed(reduction, deviation, window_size)
    # TODO: this is a naive algorithm O(length(deviation) × complexity of reduction)
    N = length(deviation)
    output = similar(deviation)
    for idx = 1:N
        window = max(1, idx-window_size):min(N, idx+window_size)
        output[idx] = reduction(view(deviation, window))
    end
end

mad(deviation) = median(abs.(deviation))
rms(deviation) = sqrt(mean(abs2.(deviation)))
rms(array, N)  = sqrt.(squeeze(mean(abs2.(array), N), N))
avg(array, N)  = squeeze(mean(array, N), N)

end

