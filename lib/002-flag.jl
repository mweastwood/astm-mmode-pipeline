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
    a_priori_antenna_flags  :: Vector{Int}
    a_priori_baseline_flags :: Vector{Tuple{Int, Int}}
    a_priori_channel_flags  :: Vector{Int}
    visibility_amplitude_threshold             :: Float64
    channel_baseline_constant_offset_threshold :: Float64
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
           get(dict, "visibility-amplitude-threshold", 0.0),
           get(dict, "channel-baseline-constant-offset-threshold", 0.0))
end

struct Flags
    # A full matrix of (baseline, channel, integration) flags is actually enormous if we are using a
    # full byte to store a `Bool` per visibility. However, we can instead use a `BitArray`. This
    # uses much less memory (generally 8 times less), but is usually slower to index. This is a
    # worthwhile tradeoff.
    bits :: BitArray{3} # Nbase × Nfreq × Ntime
    # We would also like to maintain a record of the measured RMS after channel differencing, so
    # that we can use this information to re-flag the dataset in later steps without needing to take
    # transposes of the visibilities.
    channel_difference_rms :: Vector{Float64}
end

function Flags(metadata::TTCal.Metadata)
    bits = BitArray(Nbase(metadata), Nfreq(metadata), Ntime(metadata))
    bits[:] = false
    channel_difference_rms = zeros(Nfreq(metadata)-2)
    Flags(bits, channel_difference_rms)
end

flag_baseline!(flags::Flags, baseline) = flags.bits[baseline, :, :] = true
flag_channel!(flags::Flags, channel) = flags.bits[:, channel, :] = true
flag_integration!(flags::Flags, integration) = flags.bits[:, :, integration] = true
flag_baseline_channel!(flags::Flags, baseline, channel) =
    flags.bits[baseline, channel, :] = true
flag_baseline_integration!(flags::Flags, baseline, integration) =
    flags.bits[baseline, :, integration] = true

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    flag(project, config)
    Project.touch(project, config.output)
end

function flag(project, config)
    path     = Project.workspace(project)
    metadata = Project.load(project, config.metadata, "metadata")
    visibilities = BPJSpec.load(joinpath(path, config.input))
    output = similar(visibilities, MultipleFiles(joinpath(path, config.output)))

    flags = Flags(metadata)

    println("Applying a-priori flags")
    @time a_priori_flags!(flags, config, metadata)

    println("Flagging auto-correlations")
    @time flag_autos!(flags, config, metadata)

    flag_frequency_differences = (config.visibility_amplitude_threshold > 0
                                  || config.channel_baseline_constant_offset_threshold > 0)
    if flag_frequency_differences
        println("Computing flags from frequency differences")
        transposed_visibilities = BPJSpec.load(joinpath(path, config.input_transposed))
        @time flags_from_frequency_differences!(flags, transposed_visibilities, metadata, config)
    end
    Project.save(project, config.output_flags*"-unwidened", "flags", flags)

    println("Widening flags")
    @time widen!(flags, config)
    Project.save(project, config.output_flags, "flags", flags)

    println("Applying the new flags")
    #flags = Project.load(project, config.output_flags, "flags")::Flags
    Project.set_stripe_count(project, config.output, 1)
    @time write_output(project, flags, visibilities, output, metadata)
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
    bits = permutedims(flags.bits[:, :, time], (2, 1))
    xx = @view data[1, :, :]
    yy = @view data[2, :, :]
    xx[bits] = 0
    yy[bits] = 0
    data
end

"Zero out all flagged visibilities in an array with dimensions Nbase × Ntime"
function apply_to_transpose!(data, flags, frequency)
    bits = flags.bits[:, frequency, :]
    data[bits] = 0
    data
end

"Apply a pre-existing list of flags."
function a_priori_flags!(flags, config, metadata)
    α = 1
    prg = Progress(Nbase(metadata))
    for ant1 = 1:Nant(metadata), ant2 = ant1:Nant(metadata)
        if ((ant1 in config.a_priori_antenna_flags)
                || (ant2 in config.a_priori_antenna_flags)
                || ((ant1, ant2) in config.a_priori_baseline_flags)
                || ((ant2, ant1) in config.a_priori_baseline_flags))
            flag_baseline!(flags, α)
        end
        α += 1
        next!(prg)
    end
    for β in config.a_priori_channel_flags
        flag_channel!(flags, β)
    end
    flags
end

"Flag all of the auto-correlations."
function flag_autos!(flags, config, metadata)
    α = 1
    for ant1 = 1:Nant(metadata), ant2 = ant1:Nant(metadata)
        if ant1 == ant2
            flag_baseline!(flags, α)
        end
        α += 1
    end
    flags
end

baseline_lengths(metadata) = ustrip.([norm(metadata.positions[ant1] - metadata.positions[ant2])
                                     for ant1 = 1:Nant(metadata) for ant2 = ant1:Nant(metadata)])

"Look for anomalous baselines after differencing in frequency (to cancel out the sky emission)."
function flags_from_frequency_differences!(flags, transposed_visibilities, metadata, config)
    lengths = baseline_lengths(metadata)
    load(β) = apply_to_transpose!(transposed_visibilities[β], flags, β)

    function find_flags!(flags, V1, V2, V3, Δ, range)
        if config.visibility_amplitude_threshold > 0
            for iteration = 1:3
                Δ .= difference_from_middle.(V1, V2, V3)
                _visibility_amplitude_flags!(flags, Δ, config.visibility_amplitude_threshold, range)
                apply_to_transpose!(V1, flags, range[1])
                apply_to_transpose!(V2, flags, range[2])
                apply_to_transpose!(V3, flags, range[3])
            end
        end
        if config.channel_baseline_constant_offset_threshold > 0
            Δ .= difference_from_middle.(V1, V2, V3)
            _constant_offset_flags!(flags, Δ, config.channel_baseline_constant_offset_threshold,
                                    range, lengths)
            apply_to_transpose!(V1, flags, range[1])
            apply_to_transpose!(V2, flags, range[2])
            apply_to_transpose!(V3, flags, range[3])
        end
        flags.channel_difference_rms[first(range)] = rms(Δ)
    end

    prg = Progress(Nfreq(metadata) - 2)
    range = 1:3
    V1 = load(1)
    V2 = load(2)
    V3 = load(3)
    _preexisting_flags!(flags, V1, 1)
    _preexisting_flags!(flags, V2, 2)
    _preexisting_flags!(flags, V3, 3)
    Δ  = similar(V1)
    find_flags!(flags, V1, V2, V3, Δ, range)
    next!(prg)

    while last(range) < Nfreq(metadata)
        range += 1
        V1 = V2
        V2 = V3
        V3 = load(last(range))
        _preexisting_flags!(flags, V3, last(range))
        find_flags!(flags, V1, V2, V3, Δ, range)
        next!(prg)
    end

    flags
end

"Find the pre-existing flags so that we can have a complete list."
function _preexisting_flags!(flags, V, β)
    bits = V .== 0
    flags.bits[:, β, :] .|= bits
end

"""
Compare the individual visibility amplitude to the global RMS.

After taking differences, we should be left with just noise. So we can measure the RMS of the noise
and flag any visibilities that are large compared to this RMS. A typical value for the threshold
here is `5` to avoid flagging too many visibilities due to thermal noise.
"""
function _visibility_amplitude_flags!(flags, Δ, threshold, range)
    bits = abs.(Δ) .> threshold * rms(Δ)
    for β in range
        flags.bits[:, β, :] .|= bits
    end
end

"""
Compare the time-averaged visibilities to the per-baseline RMS.

Real sky emission tends to get smeared away by the sky rotation and we've differenced in frequency
to cancel out a lot of this emission ahead of time. Therefore what remains should be noise unless
there is some terrestrial component to the visibilities (like RFI or common-mode pickup). We will
therefore flag baselines where the time-averaged visibilities are a large fraction of the RMS (note
that math says that the RMS is always larger than the amplitude of the time-averaged visibilities,
so the `threshold` here should be between 0 and 1.
"""
function _constant_offset_flags!(flags, Δ, threshold, range, lengths)
    Nbase = size(Δ, 1)
    for α = 1:Nbase
        δ = @view Δ[α, :]
        ratio = abs(avg(δ) / rms(δ))
        if is_this_baseline_unusual(ratio, threshold)
            flag_baseline_channel!(flags, α, range)
        end
    end
end

"""
Extend flags when a baseline is commonly flagged in a given integration or channel.
"""
function widen!(flags, config)
    Nbase, Nfreq, Ntime = size(flags.bits)
    for idx = 1:Ntime
        _widen_frequency(flags, idx)
    end
    for β = 1:Nfreq
        _widen_time(flags, β)
    end
end

function _widen_frequency(flags, idx)
    bits = @view flags.bits[:, :, idx]
    Nbase, Nfreq = size(bits)
    # How many frequency channels is each baseline flagged in?
    count = sum(bits, 2)
    # Flag the baseline for the entire integration if it crosses a threshold.
    for α in find(count .> 0.25 * Nfreq)
        flag_baseline_integration!(flags, α, idx)
    end
end

function _widen_time(flags, β)
    bits = @view flags.bits[:, β, :]
    Nbase, Ntime = size(bits)
    # How many integrations is each baseline flagged in?
    flagged = sum(bits, 2)
    # Flag the baseline for the entire frequency channel if it crosses a threshold.
    for α in find(flagged .> 0.25 * Ntime)
        flag_baseline_channel!(flags, α, β)
    end
end

"Get a list of all unusual baselines given the data for baselines of similar lengths."
function find_unusual_baselines(lengths, data, cutoff)
    Nbase = length(data)
    find(α -> is_this_baseline_unusual(data[α], cutoff), 1:Nbase)
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

"We're flagging data by setting it to zero. This computes the mean after discarding all zeros."
function mean_no_zero(data)
    mean_no_zero(identity, data)
end

function mean_no_zero(predicate::Function, data)
    S = mapreduce(predicate, +, data)
    C = mapreduce(iszero,    +, data)
    L = length(data)
    S / (L - C)
end

rms(vector) = sqrt(mean_no_zero(abs2, vector))
avg(vector) = mean_no_zero(vector)

doc"""
One key component of our analysis here is that we are computing differences that look like $-ν₁ +
2ν₂ - ν₃$. This is effectively a second derivative with respect to frequency, but does a better job
canceling out the power-law sky emission than the first derivative operator.

However, there are times where any of these channels may be flagged. We want the following behavior.

- **Either of the end points is flagged** - revert to the first derivative operator with the
remaining two channels
- **The middle point is flagged** - revert to the first derivative operator with the remaining two
channels
- **Both of the end points are flagged** - this channel should probably be flagged too, but that
should be the job of an explicit widening of the flags. We'll return `zero` here to exclude this
data point from the analysis.
- **The midpoint and one end point is flagged** - we cannot judge whether the remaining end point
should be flagged, but we'll return `zero` here to exclude this data point from the analysis
- **All three data points are flagged** - return `zero` to exclude this data point from
consideration

Note that we will use a multiplicative factor so that thermal noise maintains the same amplitude
between the first and second derivative operators.
"""
function difference_from_middle(x, y, z)
    xok = x != 0
    yok = y != 0
    zok = z != 0
    if xok & yok & zok
        return 2*y - x - z
    elseif xok & yok
        return √3 * (y - x)
    elseif xok & zok
        return √3 * (z - x)
    elseif yok & zok
        return √3 * (z - y)
    else
        return zero(typeof(x))
    end
end

end

