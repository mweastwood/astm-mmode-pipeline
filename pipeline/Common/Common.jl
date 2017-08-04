"""
    module Common

This module includes functions for working with certain OVRO LWA datasets on the ASTM.
"""
module Common

export getdir, getmeta
export listdadas
export baseline_index, Nbase2Nant, Nant2Nbase

using JLD
using TTCal
using ..Utility

const workspace = joinpath(dirname(@__FILE__), "..", "..", "workspace")

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
    file = joinpath(dir, "metadata-$dataset.jld")
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

baseline_index(ant1, ant2) = ((ant1-1)*(512-(ant1-2)))÷2 + (ant2-ant1+1)
Nant2Nbase(Nant) = (Nant*(Nant+1))÷2
Nbase2Nant(Nbase) = round(Int, (sqrt(1+8Nbase)-1)/2)

end

