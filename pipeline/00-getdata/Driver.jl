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

    jldopen(joinpath(getdir(spw, name), "raw-visibilities.jld2"), "w") do file
        metadata_list = Vector{TTCal.Metadata}(Ntime)
        @sync for worker in workers()
            @async while length(queue) > 0
                index = pop!(queue)
                data, metadata = remotecall_fetch(run_dada2ms, pool,
                                                  name, dadas[index], channels)
                file[@sprintf("%06d", index)] = data
                metadata_list[index] = metadata
                increment()
            end
        end
        master_metadata = metadata_list[1]
        for metadata in metadata_list[2:end]
            TTCal.merge!(master_metadata, metadata, axis=:time)
        end
        file["metadata"] = master_metadata
    end
    nothing
end

function run_dada2ms(name, dada, channels)
    local data, metadata
    try
        ms = dada2ms(dada, name)
        raw_data = ms["DATA"] :: Array{Complex64, 3}
        metadata = TTCal.Metadata(ms)
        TTCal.slice!(metadata, channels, axis=:frequency)
        keep = [true; false; false; true]
        data = raw_data[keep, channels, :]
        Tables.delete(ms)
    catch exception
        println(dada)
        println(exception)
        rethrow(exception)
    end
    data, metadata
end

end

