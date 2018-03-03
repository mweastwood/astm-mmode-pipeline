"""
    module Common

This module includes functions for working with certain OVRO LWA datasets on the ASTM.
"""
module Common

export getdir, getmeta, getfreq
export listdadas
export baseline_index, Nbase2Nant, Nant2Nbase
export launch_maximum_workers

using FileIO, JLD2
using TTCal
using ..Utility

const workspace = joinpath(@__DIR__, "..", "..", "workspace")

function getdir(spw)
    dir = joinpath(workspace, @sprintf("spw%02d", spw))
    isdir(dir) || mkdir(dir)
    dir
end

"""
    listdadas(spw, dataset)

Return a list of the path to every dada file from the given spectral window.
"""
function listdadas(spw, dataset)
    spw = fix_spw_offset(spw, dataset)
    str = @sprintf("%02d", spw)
    if dataset == "100hr"
        dir = "/lustre/data/2016-03-19_100hour_run"
        prefix = "2016-03-19-01:44:01"
    elseif dataset == "rainy"
        dir = "/lustre/data/2017-02-17_24hour_run"
        prefix = "2017-02-11-02:36:59"
    else
        dir = joinpath("/lustre/data", dataset)
        prefix = ""
    end
    files = readdir(joinpath(dir, str))
    filter!(files) do file
        startswith(file, prefix)
    end
    sort!(files)
    for idx = 1:length(files)
        files[idx] = joinpath(dir, str, files[idx])
    end
    files
end

# The rainy data is offset from the 100 hour run by one spectral window.
fix_spw_offset(spw, dataset) = dataset == "rainy"? spw - 1 : spw

function getmeta(spw, dataset)
    dir = getdir(spw)
    file = joinpath(dir, "metadata-$dataset.jld2")
    if isfile(file)
        meta = load(file, "metadata")
        return meta::Metadata
    else
        dadas = listdadas(spw, dataset)
        ms, path = dada2ms(dadas[1], dataset)
        meta = Metadata(ms)
        finalize(ms)
        rm(path, recursive=true)
        save(file, "metadata", meta)
        return meta::Metadata
    end
end

function getfreq(spw)
    meta = getmeta(spw, "rainy")
    meta.channels[55]
end

getfrequencies(spws, dataset) = [getfreq(spw) for spw in spws]

baseline_index(ant1, ant2) = ((ant1-1)*(512-(ant1-2)))÷2 + (ant2-ant1+1)
Nant2Nbase(Nant) = (Nant*(Nant+1))÷2
Nbase2Nant(Nbase) = round(Int, (sqrt(1+8Nbase)-1)/2)

function get_workers()
    futures = [remotecall(() -> chomp(readstring(`hostname`)), worker) for worker in workers()]
    workers_dict = Dict{String, Vector{Int}}()
    for (future, worker) in zip(futures, workers())
        hostname = fetch(future)
        if haskey(workers_dict, hostname)
            push!(workers_dict[hostname], worker)
        else
            workers_dict[hostname] = [worker]
        end
    end
    workers_dict
end

function launch_maximum_workers()
    workers  = get_workers()
    machines = ("astm04", "astm05", "astm06", "astm07", "astm08", "astm09", "astm10", "astm11")
    funky = ("astm07",) # behaving poorly at the moment
    list = Tuple{String, Int}[]
    for machine in machines
        machine in funky && continue
        if haskey(workers, machine)
            N = length(workers)
            if N < 8
                push!(list, (machine, N-1))
            end
        else
            push!(list, (machine, 8))
        end
    end
    addprocs(list)
end

end

