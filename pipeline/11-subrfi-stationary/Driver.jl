module Driver

using JLD2
using ProgressMeter
using TTCal
using Unitful

include("../lib/Common.jl");  using .Common
include("../lib/DADA2MS.jl"); using .DADA2MS
include("../lib/WSClean.jl"); using .WSClean

function subrfi_stationary(spw, name)
    subrfi(spw, name, "fitrfi-stationary-coherencies.jld2",
                      "flagged-calibrated-visibilities.jld2",
                      "subrfi-stationary-visibilities.jld2")
end

function subrfi_impulsive(spw, name)
    subrfi(spw, name, "fitrfi-impulsive-coherencies.jld2",
                      "subrfi-stationary-visibilities.jld2",
                      "subrfi-impulsive-visibilities.jld2")
end

function subrfi(spw, name, coherencies_name, input_name, output_name)
    local coherencies
    jldopen(joinpath(getdir(spw, name), coherencies_name), "r") do file
        coherencies = file["coherencies"]
    end
    jldopen(joinpath(getdir(spw, name), input_name), "r") do input_file
        metadata = input_file["metadata"]
        amplitude = zeros(2, Nfreq(metadata), Ntime(metadata), length(coherencies))

        pool  = CachingPool(workers())
        queue = collect(1:Ntime(metadata))

        lck = ReentrantLock()
        prg = Progress(length(queue))
        increment() = (lock(lck); next!(prg); unlock(lck))

        jldopen(joinpath(getdir(spw, name), output_name), "w") do output_file
            @sync for worker in workers()
                @async while length(queue) > 0
                    index = pop!(queue)
                    raw_data = input_file[o6d(index)]
                    sub_data, amp = remotecall_fetch(_subrfi, pool, raw_data, metadata, coherencies)
                    amplitude[:, :, index, :] = amp
                    output_file[o6d(index)] = sub_data
                    increment()
                end
            end
            output_file["amplitude"] = amplitude
            output_file["metadata"]  = metadata
        end
    end
end

#function test(spw, name, integration)
#    local coherencies
#    jldopen(joinpath(getdir(spw, name), "smeared-visibilities.jld2"), "r") do file
#        coherencies = file["coherencies"]
#    end
#    jldopen(joinpath(getdir(spw, name), "calibrated-visibilities.jld2"), "r") do input_file
#        metadata = input_file["metadata"]
#        raw_data = input_file[o6d(integration)]
#
#        println("# before")
#        image(spw, name, integration, array_to_ttcal(raw_data, metadata, integration),
#              "/lustre/mweastwood/tmp/subrfi-before-$integration")
#
#        println("# after")
#        sub_data, amp = _subrfi(raw_data, metadata, coherencies)
#        @show amp
#        image(spw, name, integration, array_to_ttcal(sub_data, metadata, integration),
#              "/lustre/mweastwood/tmp/subrfi-after-$integration")
#    end
#    nothing
#end

function flag_short_baselines(metadata, minuvw=15.0)
    flags = fill(false, Nbase(metadata))
    ν = minimum(metadata.frequencies)
    λ = u"c" / ν
    α = 1
    for antenna1 = 1:Nant(metadata), antenna2 = antenna1:Nant(metadata)
        baseline_vector = metadata.positions[antenna1] - metadata.positions[antenna2]
        baseline_length = norm(baseline_vector)
        if baseline_length < minuvw * λ
            flags[α] = true
        end
        α += 1
    end
    flags
end

function _subrfi(data, metadata, coherencies)
    original_flags = data .== 0
    short_baselines = flag_short_baselines(metadata, 15.0)
    Npol, Nfreq, Nbase = size(data)
    amplitude = zeros(Npol, Nfreq, length(coherencies))
    output    = zeros(Complex128, Npol, Nfreq, Nbase)
    for freq = 1:Nfreq, pol = 1:Npol
        x = data[pol, freq, :]
        for (index, coherency) in enumerate(coherencies)
            y = coherency[pol, freq, :]
            flags = original_flags[pol, freq, :]
            y[flags] = 0
            flags .|= short_baselines
            amplitude[pol, freq, index] = sub!(x, y, flags)
        end
        output[pol, freq, :] = x
    end
    output[original_flags] = 0
    output, amplitude
end

function sub!(x, y, flags)
    xf = x[.!flags]
    yf = y[.!flags]
    xx = [xf; conj(xf)]
    yy = [yf; conj(yf)]
    numerator   = dot(xx, yy)
    denominator = dot(yy, yy)
    if denominator != 0
        scale  = real(numerator/denominator)
        to_sub = scale.*y
        # short baselines were not used while fitting for how much to subtract so we also shouldn't
        # subtract anything from them
        to_sub[flags] = 0
        @. x -= to_sub
    else
        scale = 0.0
    end
    scale
end

end

