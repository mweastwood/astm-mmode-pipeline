module Driver

using JLD2
using ProgressMeter
using TTCal

include("../lib/Common.jl"); using .Common

function subrfi(spw, name)
    local coherencies
    jldopen(joinpath(getdir(spw, name), "smeared-visibilities.jld2"), "r") do file
        coherencies = file["coherencies"]
    end
    jldopen(joinpath(getdir(spw, name), "calibrated-visibilities.jld2"), "r") do input_file
        metadata = input_file["metadata"]
        amplitude = zeros(2, Nfreq(metadata), Ntime(metadata), length(coherencies))

        pool  = CachingPool(workers())
        queue = collect(1:Ntime(metadata))

        lck = ReentrantLock()
        prg = Progress(length(queue))
        increment() = (lock(lck); next!(prg); unlock(lck))

        jldopen(joinpath(getdir(spw, name), "rfiremoved-visibilities.jld2"), "w") do output_file
            @sync for worker in workers()
                @async while length(queue) > 0
                    index = pop!(queue)
                    raw_data = input_file[o6d(index)]
                    sub_data, amp = remotecall_fetch(_subrfi, pool, raw_data, coherencies)
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

function _subrfi(data, coherencies)
    Npol, Nfreq, Nbase = size(data)
    amplitude = zeros(Npol, Nfreq, length(coherencies))
    output    = zeros(Complex128, Npol, Nfreq, Nbase)
    for pol = 1:Npol, freq = 1:Nfreq
        x = data[pol, freq, :]
        for (index, coherency) in enumerate(coherencies)
            y = coherency[pol, freq, :]
            amplitude[pol, freq, index] = sub!(x, y)
        end
        output[pol, freq, :] = x
    end
    output, amplitude
end

function sub!(x, y)
    xx = [x; conj(x)]
    yy = [y; conj(y)]
    scale = real(dot(xx, yy)/dot(yy, yy))
    @. x -= scale*y
    scale
end

end

