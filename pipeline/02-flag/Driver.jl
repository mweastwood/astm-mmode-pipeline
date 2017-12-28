module Driver

using FileIO, JLD2
using ProgressMeter
using TTCal, Unitful
using Dierckx

include("../lib/Common.jl"); using .Common

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

function accumulate_time(file, metadata, flags)
    output = zeros(Complex128, Nbase(metadata), Nfreq(metadata))
    count  = zeros(       Int, Nbase(metadata), Nfreq(metadata))
    prg = Progress(Nfreq(metadata))
    for frequency = 1:Nfreq(metadata)
        data = file[o6d(frequency)]
        apply_to_transpose!(data, flags, frequency)
        @views output[:, frequency] .+= squeeze(sum(data[1, :, :], 2), 2)
        @views output[:, frequency] .+= squeeze(sum(data[2, :, :], 2), 2)
        @views count[:, frequency]  .+= squeeze(sum(data[1, :, :] .!= 0, 2), 2)
        @views count[:, frequency]  .+= squeeze(sum(data[2, :, :] .!= 0, 2), 2)
        next!(prg)
    end
    count[count .== 0] .= 1
    output ./= count
    output
end

function accumulate_frequency(file, metadata, flags)
    output = zeros(Complex128, Nbase(metadata), Ntime(metadata))
    count  = zeros(       Int, Nbase(metadata), Ntime(metadata))
    prg = Progress(Nfreq(metadata))
    for frequency = 1:Nfreq(metadata)
        data = file[o6d(frequency)]
        apply_to_transpose!(data, flags, frequency)
        @views output .+= data[1, :, :]
        @views output .+= data[2, :, :]
        @views count  .+= data[1, :, :] .!= 0
        @views count  .+= data[2, :, :] .!= 0
        next!(prg)
    end
    count[count .== 0] .= 1
    output ./= count
    output
end

include("a-priori-flags.jl")
include("integration-flags.jl")
include("baseline-flags.jl")
include("channel-flags.jl")

function flag(spw, name)
    path = getdir(spw, name)
    local flags
    jldopen(joinpath(path, "transposed-visibilities.jld2"), "r") do file
        metadata = file["metadata"]
        flags = Flags(metadata)
        a_priori_flags!(flags, spw, name)

        data = accumulate_frequency(file, metadata, flags)
        save(joinpath(path, "flagging-checkpoint-1.jld2"), "data", data)
        #@time data = load(joinpath(path, "flagging-checkpoint-1.jld2"), "data")

        apply_baseline_flags!(data, flags, metadata)
        apply_integration_flags!(data, flags)

        # (it turns out we don't really need channel flags yet, so we've left the rest out for now)

        #data = accumulate_time(file, metadata, flags)
        #save(joinpath(path, "flagging-checkpoint-2.jld2"), "data", data)
        #@time data = load(joinpath(path, "flagging-checkpoint-2.jld2"), "acc")
        #apply_channel_flags!(data, flags)

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
                apply!(raw_data, flags, time)
                output_file[o6d(time)] = raw_data
                next!(prg)
            end
            output_file["metadata"] = metadata
        end
    end
end

end

