module Driver

using CasaCore.Measures
using CasaCore.Tables
using JLD2
using ProgressMeter
using TTCal

include("../lib/Common.jl");  using .Common
include("../lib/DADA2MS.jl"); using .DADA2MS
include("../lib/WSClean.jl"); using .WSClean

const source_dictionary = Dict("Cyg A" => Direction(dir"J2000", "19h59m28.35663s", "+40d44m02.0970s"),
                               "Cas A" => Direction(dir"J2000", "23h23m24s", "58d48m54s"),
                               "Vir A" => Direction(dir"J2000", "12h30m49.42338s", "+12d23m28.0439s"),
                               "Tau A" => Direction(dir"J2000", "05h34m31.94s", "+22d00m52.2s"),
                               "Her A" => Direction(dir"J2000", "16h51m11.4s", "+04d59m20s"),
                               "Cen A" => Direction(dir"J2000", "13h25m27.61507s", "-43d01m08.8053s"),
                               "Sun"   => Direction(dir"SUN"))

function residuals(spw, name)
    for source in ("Cyg A", "Cas A")
        residuals(spw, name, source)
    end
end

function residuals(spw, name, source::String)
    image = residuals(spw, name, source_dictionary[source])
    @show image joinpath(getdir(spw, name), lowercase(replace(source, " ", "-"))*".fits")
    mv(image, joinpath(getdir(spw, name), lowercase(replace(source, " ", "-"))*".fits"),
       remove_destination=true)
end

function residuals(spw, name, direction::Direction)
    local accumulation, metadata
    jldopen(joinpath(getdir(spw, name), "peeled-visibilities.jld2"), "r") do file
        metadata = file["metadata"]
        accumulation = zeros(Complex128, 2, Nfreq(metadata), Nbase(metadata))

        pool  = CachingPool(workers())
        #queue = collect(1:Ntime(metadata))
        queue = collect(1:2)

        lck = ReentrantLock()
        prg = Progress(length(queue))
        increment() = (lock(lck); next!(prg); unlock(lck))

        @sync for worker in workers()
            @async while length(queue) > 0
                index = pop!(queue)
                raw_data = file[o6d(index)]
                data = remotecall_fetch(do_the_work, pool, spw, name, raw_data,
                                        metadata, index, direction)
                accumulation .+= data
                increment()
            end
        end
        #for time = 1:Ntime(metadata)
        #    data = file[o6d(time)]
        #    accumulation .+= do_the_work(spw, name, data, metadata, time, direction)
        #    next!(prg)
        #end
    end
    do_the_image(spw, name, accumulation, metadata.frequencies)
end

function do_the_work(spw, name, data, metadata, time, direction)
    ttcal = array_to_ttcal(data, metadata, time)
    Common.flag!(spw, name, ttcal)
    rotate_phase_center!(ttcal, direction)
    ttcal_to_array(ttcal)
end

function do_the_image(spw, name, accumulation, frequencies)
    dada = first(listdadas(spw, name))
    ms = dada2ms(spw, dada, name)
    metadata = TTCal.Metadata(ms)
    output = zeros(Complex64, 4, Nfreq(metadata), Nbase(metadata))
    for (idx, ν) in enumerate(frequencies)
        jdx = first(find(ν .== metadata.frequencies))
        for α = 1:Nbase(metadata)
            output[1, jdx, α] = accumulation[1, idx, α]
            output[4, jdx, α] = accumulation[2, idx, α]
        end
    end
    ms["CORRECTED_DATA"] = output
    Tables.close(ms)
    image_path = "/dev/shm/mweastwood/image"
    name = wsclean(ms.path, image_path)
    Tables.delete(ms)
    image_path*".fits"
end

end

