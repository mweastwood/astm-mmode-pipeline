module Driver

using CasaCore.Measures
using JLD2
using ProgressMeter
using TTCal

include("../lib/Common.jl"); using .Common

const source_dictionary = Dict("Cyg A" => Direction(dir"J2000", "19h59m28.35663s", "+40d44m02.0970s"),
                               "Cas A" => Direction(dir"J2000", "23h23m24s", "58d48m54s"),
                               "Vir A" => Direction(dir"J2000", "12h30m49.42338s", "+12d23m28.0439s"),
                               "Tau A" => Direction(dir"J2000", "05h34m31.94s", "+22d00m52.2s"),
                               "Her A" => Direction(dir"J2000", "16h51m11.4s", "+04d59m20s"),
                               "Cen A" => Direction(dir"J2000", "13h25m27.61507s", "-43d01m08.8053s"),
                               "Sun"   => Direction(dir"SUN"))

function residuals(spw, name)
    #for source in ("Cyg A", "Cas A")
    for source in ("Sun")
        residuals(spw, name, source)
    end
end

function residuals(spw, name, source::String)
    residuals(spw, name, source_dictionary[source])
end

function residuals(spw, name, direction::Direction)
    local accumulation, metadata
    jldopen(joinpath(getdir(spw, name), "peeled-visibilities.jld2"), "r") do file
        metadata = file["metadata"]
        accumulation = zeros(Complex128, 2, Nfreq(metadata), Nbase(metadata))

        pool  = CachingPool(workers())
        queue = collect(1:Ntime(metadata))

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
    dataset = array_to_ttcal(accumulation, metadata, 1)
    image(spw, name, 1, dataset, joinpath(getdir(spw, name), "residual"), del=false)
end

function do_the_work(spw, name, data, metadata, time, direction)
    ttcal = array_to_ttcal(data, metadata, time)
    rotate_phase_center!(ttcal, direction)
    ttcal_to_array(ttcal)
end

end

