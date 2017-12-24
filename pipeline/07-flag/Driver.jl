module Driver

using JLD2
using ProgressMeter
using TTCal
using Dierckx

include("../lib/Common.jl"); using .Common

function flag(spw, name)
    path = getdir(spw, name)
    local flags
    jldopen(joinpath(path, "transposed-visibilities.jld2"), "r") do input_file
        metadata = input_file["metadata"]
        flags = _flag(spw, name, @time(input_file["000001"]))
        for frequency = 2:Nfreq(metadata)
            @time raw_data = input_file[o6d(frequency)]
            flags .|= _flag(spw, name, raw_data)
        end
    end
    output(spw, name, flags)
    flags
end

function output(spw, name, flags)
    path = getdir(spw, name)
    jldopen(joinpath(path, "raw-visibilities.jld2"), "r") do input_file
        metadata = input_file["metadata"]
        jldopen(joinpath(path, "flagged-visibilities.jld2"), "w") do output_file
            prg = Progress(Ntime(metadata))
            for time = 1:Ntime(metadata)
                raw_data = input_file[o6d(time)]
                integration_flags = flags[:, time]
                for frequency = 1:Nfreq(metadata)
                    raw_data[1, frequency, integration_flags] = 0
                    raw_data[2, frequency, integration_flags] = 0
                end
                output_file[o6d(time)] = raw_data
                next!(prg)
            end
            output_file["metadata"] = metadata
        end
    end
end

function _flag(spw, name, data::Array{Complex128, 3})
    Npol, Nbase, Ntime = size(data)
    flags = fill(false, Nbase, Ntime)
    antenna_flags = read_antenna_flags(spw, name)
    baseline_flags = read_baseline_flags(spw, name)
    a_priori_flags!(data, flags, antenna_flags, baseline_flags)
    a_posteriori_flags!(data, flags)
end

function a_priori_flags!(data, flags, antenna_flags, baseline_flags)
    Nbase = size(data, 2)
    Nant  = Nbase2Nant(Nbase)
    α = 1
    for ant1 = 1:Nant, ant2 = ant1:Nant
        if ((ant1 == ant2) || (ant1 in antenna_flags)
                           || (ant2 in antenna_flags)
                           || ((ant1, ant2) in baseline_flags)
                           || ((ant2, ant1) in baseline_flags))
            data[:, α, :] = 0
            flags[α, :] = true
        end
        α += 1
    end
end

function a_posteriori_flags!(data, flags)
    Nbase = size(data, 2)
    prg = Progress(Nbase)
    for α = 1:Nbase
        if !all(view(flags, α, :))
            time_series = view(data, 1, α, :) + view(data, 2, α, :)
            flags[α, :] = threshold_flag(time_series)
        end
        next!(prg)
    end
    flags
end

#using PyPlot

function threshold_flag(data)
    x = 1:length(data)
    y = abs.(data)
    knots = x[2:10:end-1]
    spline = Spline1D(x, y, knots)
    deviation = abs.(y .- spline.(x))
    mad1 = median(deviation) # this is a lot faster and almost as good
    #mad2 = windowed_mad(deviation)
    flags = deviation .> 10 .* mad1

    #figure(1); clf()
    #plot(x, y, label="data")
    #plot(x, spline.(x), label="spline")
    #plot(x, spline.(x) .+ 5 .* mad1, label="unwindowed")
    #plot(x, spline.(x) .+ 5 .* mad2, label="windowed")
    #legend()

    flags
end

function windowed_mad(deviation)
    # the system temperature varies with time, computing the median-absolute-deviation within a
    # window allows our threshold to also vary with time
    N = length(deviation)
    output = similar(deviation)
    for idx = 1:N
        window = max(1, idx-100):min(N, idx+100)
        δ = view(deviation, window)
        output[idx] = median(δ)
    end
    output
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

end

