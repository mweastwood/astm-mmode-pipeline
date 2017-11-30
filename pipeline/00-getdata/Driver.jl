module Driver

using CasaCore.Tables
using JLD2
using ProgressMeter
using TTCal

include("../lib/Common.jl");  using .Common
include("../lib/DADA2MS.jl"); using .DADA2MS

function getdata(spw, dataset)
    dadas = listdadas(spw, dataset)
    getdata(spw, 50:60, 1:length(dadas), dataset)
end

function getdata_middle_channel(spw, dataset)
    dadas = listdadas(spw, dataset)
    getdata(spw, 55:55, 1:length(dadas), dataset)
end

function getdata(spw, channels, range, dataset)
    dadas = listdadas(spw, dataset)[range]
    Ntime = length(range)
    Nfreq = length(channels)

    pool  = CachingPool(workers())
    queue = collect(1:Ntime)

    lck = ReentrantLock()
    prg = Progress(length(queue))
    increment() = (lock(lck); next!(prg); unlock(lck))

    path = getdir(spw, dataset)
    isdir(path) || mkpath(path)
    jldopen(joinpath(path, "raw-visibilities.jld2"), "w") do file
        @sync for worker in workers()
            @async while length(queue) > 0
                integration = pop!(queue)
                dada = dadas[integration]
                data, metadata = remotecall_fetch(do_the_work, pool, dataset, dada, channels)
                write_to_disk(file, integration, data, metadata)
                increment()
            end
        end
    end
    nothing
end

function write_to_disk(file, integration, data, metadata)
    objectname = @sprintf("%06d", integration)
    file[objectname] = data
    objectname = @sprintf("%06d-metadata", integration)
    file[objectname] = metadata
end

function do_the_work(dataset, dada, channels)
    local data, metadata
    try
        ms, path = dada2ms(dada, dataset)
        raw_data = ms["DATA"] :: Array{Complex64, 3}
        metadata = TTCal.Metadata(ms)
        # horrible hack until it is possible to modify structs in place
        frequencies = metadata.frequencies[channels]
        resize!(metadata.frequencies, length(frequencies))
        metadata.frequencies[:] = frequencies
        # discard the xy and yx correlations because we don't really have the information to
        # calibrate them (no polarization calibration)
        keep = [true; false; false; true]
        data = raw_data[keep, channels, :]
        Tables.delete(ms)
    catch exception
        # oops, something broke
        println(dada)
        println(exception)
        time   = NaN
        output = nothing
    end
    data, metadata
end

end

