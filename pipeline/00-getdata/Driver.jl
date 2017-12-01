module Driver

using CasaCore.Tables
using JLD2
using ProgressMeter
using TTCal

include("../lib/Common.jl");  using .Common
include("../lib/DADA2MS.jl"); using .DADA2MS

function getdata(spw, name)
    dadas = listdadas(spw, name)
    getdata(spw, 53:57, name)
end

function getdata_middle_channel(spw, name)
    dadas = listdadas(spw, name)
    getdata(spw, 55:55, name)
end

function getdata(spw, channels, name)
    dadas = listdadas(spw, name)
    Ntime = length(dadas)
    Nfreq = length(channels)

    pool  = CachingPool(workers())
    queue = collect(1:Ntime)

    lck = ReentrantLock()
    prg = Progress(length(queue))
    increment() = (lock(lck); next!(prg); unlock(lck))

    output_path = joinpath(getdir(spw, name), "raw-visibilities.jld2")
    jldopen(output_path, "w") do file
        times = Float64[]
        @sync for worker in workers()
            @async while length(queue) > 0
                index = pop!(queue)
                data, time, frequencies = remotecall_fetch(run_dada2ms, pool,
                                                           name, dadas[index], channels)
                file[@sprintf("%06d", index)] = data
                push!(times, time)
                if index == 1
                    file["frequencies"] = frequencies
                end
                increment()
            end
        end
        file["times"] = sort!(times)
        file["Ntime"] = Ntime
        file["Nfreq"] = Nfreq
    end
    nothing
end

function run_dada2ms(name, dada, channels)
    local data, time, frequencies
    try
        ms = dada2ms(dada, name)
        raw_data = ms["DATA"] :: Array{Complex64, 3}
        spw = ms[kw"SPECTRAL_WINDOW"]
        frequencies = spw["CHAN_FREQ", 1][channels]
        Tables.close(spw)
        time = ms["TIME", 1]
        keep = [true; false; false; true]
        data = raw_data[keep, channels, :]
        Tables.delete(ms)
    catch exception
        println(dada)
        println(exception)
        rethrow(exception)
    end
    data, time, frequencies
end

end

