"""
    module Common

This module includes functions for working with certain OVRO LWA datasets on the ASTM.
"""
module Common

export getdir, getfreq
export listdadas
export baseline_index, Nbase2Nant, Nant2Nbase
export ttcal_to_array, array_to_ttcal
export o6d

using CasaCore.Measures
using CasaCore.Tables
using FileIO, JLD2
using TTCal
using Unitful

include("DADA2MS.jl"); using .DADA2MS

const workspace = joinpath(@__DIR__, "..", "..", "workspace")

function getdir(spw)
    dir = joinpath(workspace, @sprintf("spw%02d", spw))
    isdir(dir) || mkpath(dir)
    dir
end

function getdir(spw, dataset)
    dir = joinpath(getdir(spw), dataset)
    isdir(dir) || mkpath(dir)
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

o6d(i) = @sprintf("%06d", i)

#function getmeta(spw, dataset)::TTCal.Metadata
#    dir = getdir(spw, dataset)
#    file = joinpath(dir, "metadata.jld2")
#    if isfile(file)
#        meta = load(file, "metadata")
#        return meta
#    else
#        dadas = listdadas(spw, dataset)
#        ms = dada2ms(dadas[1], dataset)
#        meta = TTCal.Metadata(ms)
#        Tables.delete(ms)
#        save(file, "metadata", meta)
#        return meta
#    end
#end

#baseline_index(ant1, ant2) = ((ant1-1)*(512-(ant1-2)))÷2 + (ant2-ant1+1)
Nant2Nbase(Nant) = (Nant*(Nant+1))÷2
Nbase2Nant(Nbase) = round(Int, (sqrt(1+8Nbase)-1)/2)

# a priori flags

function flag!(spw, dataset, ttcal_dataset)
    antenna_flags  = flag_antennas(spw, dataset)
    baseline_flags = flag_baselines(spw, dataset)
    TTCal.flag_antennas!(ttcal_dataset, antenna_flags)
    TTCal.flag_baselines!(ttcal_dataset, baseline_flags)
end

# antenna flags

function flag_antennas(spw, dataset)
    flags = Int[]
    directory = joinpath(Common.workspace, "flags")
    for file in (@sprintf("%s.ants", dataset),
                 @sprintf("%s-spw%02d.ants", dataset, spw))
        isfile(joinpath(directory, file)) || continue
        antennas = read_antenna_flags(joinpath(directory, file))
        for ant in antennas
            push!(flags, ant)
        end
    end
    flags
end

function read_antenna_flags(path) :: Vector{Int}
    flags = readdlm(path, Int)
    reshape(flags, length(flags))
end

# baseline flags

function flag_baselines(spw, dataset)
    flags = Tuple{Int, Int}[]
    directory = joinpath(Common.workspace, "flags")
    for file in (@sprintf("%s.bl", dataset),
                 @sprintf("%s-spw%02d.bl", dataset, spw))
        isfile(joinpath(directory, file)) || continue
        baselines = read_baseline_flags(joinpath(directory, file))
        for idx = 1:size(baselines, 1)
            ant1 = baselines[idx, 1]
            ant2 = baselines[idx, 2]
            push!(flags, (ant1, ant2))
        end
    end
    flags
end

function read_baseline_flags(path) :: Matrix{Int}
    flags = readdlm(path, '&', Int)
    flags
end

end

