"""
    module Project

This module includes functions for working with OVRO-LWA datasets on the ASTM.
"""
module Project

using YAML

struct ProjectMetadata
    name :: String
    hidden :: String
end

function load(file)
    dict = YAML.load(open(file))
    ProjectMetadata(dict["name"], joinpath(dirname(file), ".pipeline"))
end

function workspace(metadata::ProjectMetadata)
    path = joinpath("/lustre/mweastwood/mmode-analysis-workspace", metadata.name)
    isdir(path) || mkpath(path)
    path
end

function temp()
    path = "/dev/shm/mweastwood"
    isdir(path) || mkpath(path)
    path
end

lib() = @__DIR__
bin() = normpath(lib(), "..", "bin")

function touch(metadata, filename)
    isdir(metadata.hidden) || mkpath(metadata.hidden)
    Base.touch(joinpath(metadata.hidden, filename))
end

#export getdir, getfreq
#export listdadas
#export baseline_index, Nbase2Nant, Nant2Nbase
#export ttcal_to_array, array_to_ttcal
#export o6d
#export image
#
#using CasaCore.Measures
#using CasaCore.Tables
#using FileIO, JLD2
#using TTCal
#using Unitful
#
#include("DADA2MS.jl"); using .DADA2MS
#include("WSClean.jl"); using .WSClean
#
#const workspace = joinpath(@__DIR__, "..", "..", "workspace")
#
#function getdir(spw)
#    dir = joinpath(workspace, @sprintf("spw%02d", spw))
#    isdir(dir) || mkpath(dir)
#    dir
#end
#
#function getdir(spw, dataset)
#    dir = joinpath(getdir(spw), dataset)
#    isdir(dir) || mkpath(dir)
#    normpath(dir)
#end
#
#"""
#    listdadas(spw, dataset)
#
#Return a list of the path to every dada file from the given spectral window.
#"""
#function listdadas(spw, dataset)
#    spw = fix_spw_offset(spw, dataset)
#    str = @sprintf("%02d", spw)
#    if dataset == "100hr"
#        dir = "/lustre/data/2016-03-19_100hour_run"
#        prefix = "2016-03-19-01:44:01"
#    elseif dataset == "rainy"
#        dir = "/lustre/data/2017-02-17_24hour_run"
#        prefix = "2017-02-11-02:36:59"
#    else
#        dir = joinpath("/lustre/data", dataset)
#        prefix = ""
#    end
#    files = readdir(joinpath(dir, str))
#    filter!(files) do file
#        startswith(file, prefix)
#    end
#    sort!(files)
#    for idx = 1:length(files)
#        files[idx] = joinpath(dir, str, files[idx])
#    end
#    files
#end
#
## The rainy data is offset from the 100 hour run by one spectral window.
#fix_spw_offset(spw, dataset) = dataset == "rainy"? spw - 1 : spw
#
#o6d(i) = @sprintf("%06d", i)
#
##function getmeta(spw, dataset)::TTCal.Metadata
##    dir = getdir(spw, dataset)
##    file = joinpath(dir, "metadata.jld2")
##    if isfile(file)
##        meta = load(file, "metadata")
##        return meta
##    else
##        dadas = listdadas(spw, dataset)
##        ms = dada2ms(dadas[1], dataset)
##        meta = TTCal.Metadata(ms)
##        Tables.delete(ms)
##        save(file, "metadata", meta)
##        return meta
##    end
##end
#
##baseline_index(ant1, ant2) = ((ant1-1)*(512-(ant1-2)))÷2 + (ant2-ant1+1)
#Nant2Nbase(Nant) = (Nant*(Nant+1))÷2
#Nbase2Nant(Nbase) = round(Int, (sqrt(1+8Nbase)-1)/2)
#
#function array_to_ttcal(array, metadata, time, T=TTCal.Dual)
#    # this assumes one time slice
#    metadata = deepcopy(metadata)
#    TTCal.slice!(metadata, time, axis=:time)
#    ttcal_dataset = TTCal.Dataset(metadata, polarization=T)
#    for frequency in 1:Nfreq(metadata)
#        visibilities = ttcal_dataset[frequency, 1]
#        α = 1
#        for antenna1 = 1:Nant(metadata), antenna2 = antenna1:Nant(metadata)
#            J = pack_jones_matrix(array, frequency, α, T)
#            if J != zero(typeof(J))
#                visibilities[antenna1, antenna2] = J
#            end
#            α += 1
#        end
#    end
#    ttcal_dataset
#end
#
#function pack_jones_matrix(array, frequency, α, ::Type{TTCal.Dual})
#    TTCal.DiagonalJonesMatrix(array[1, frequency, α], array[2, frequency, α])
#end
#function pack_jones_matrix(array, frequency, α, ::Type{TTCal.XX})
#    array[1, frequency, α]
#end
#function pack_jones_matrix(array, frequency, α, ::Type{TTCal.YY})
#    array[2, frequency, α]
#end
#
#function ttcal_to_array(ttcal_dataset)
#    # this assumes one time slice
#    data = zeros(Complex128, 2, Nfreq(ttcal_dataset), Nbase(ttcal_dataset))
#    for frequency in 1:Nfreq(ttcal_dataset)
#        visibilities = ttcal_dataset[frequency, 1]
#        α = 1
#        for antenna1 = 1:Nant(ttcal_dataset), antenna2 = antenna1:Nant(ttcal_dataset)
#            J = visibilities[antenna1, antenna2]
#            unpack_jones_matrix!(data, frequency, α, J, TTCal.polarization(ttcal_dataset))
#            α += 1
#        end
#    end
#    data
#end
#
#function unpack_jones_matrix!(data, frequency, α, J, ::Type{TTCal.Dual})
#    data[1, frequency, α] = J.xx
#    data[2, frequency, α] = J.yy
#end
#function unpack_jones_matrix!(data, frequency, α, J, ::Type{TTCal.XX})
#    data[1, frequency, α] = J
#end
#function unpack_jones_matrix!(data, frequency, α, J, ::Type{TTCal.YY})
#    data[2, frequency, α] = J
#end
#
#function image(spw, name, integration, input, fits; del=true)
#    dadas = listdadas(spw, name)
#    dada  = dadas[integration]
#    filename = replace(basename(dada), "dada", "ms")
#    filename = @sprintf("spw%02d-%s", spw, filename)
#    path = joinpath("/dev/shm/mweastwood", filename)
#    if !isdir(path)
#        ms = dada2ms(spw, dada, name)
#    else
#        ms = Tables.open(path, write=true)
#    end
#    metadata = TTCal.Metadata(ms)
#    output = TTCal.Dataset(metadata, polarization=TTCal.polarization(input))
#    for idx = 1:Nfreq(input)
#        jdx = find(metadata.frequencies .== input.metadata.frequencies[idx])[1]
#        input_vis  =  input[idx, 1]
#        output_vis = output[jdx, 1]
#        for ant1 = 1:Nant(input), ant2=ant1:Nant(input)
#            output_vis[ant1, ant2] = input_vis[ant1, ant2]
#        end
#    end
#    TTCal.write(ms, output, column="CORRECTED_DATA")
#    Tables.close(ms)
#    wsclean(ms.path, fits)
#    del && Tables.delete(ms)
#end

end

