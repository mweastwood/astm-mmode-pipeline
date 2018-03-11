"""
    module Project

This module includes functions for working with OVRO-LWA datasets on the ASTM.
"""
module Project

using JLD2
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

function set_stripe_count(project, directory, N)
    path = joinpath(workspace(project), directory)
    isdir(path) || mkpath(path)
    run(`lfs setstripe -c $N $path`)
end

function load(project, filename, objectname)
    jldopen(joinpath(workspace(project), filename*".jld2"), false, false, false, IOStream) do file
        return file[objectname]
    end
end

function save(project, filename, objectname, object)
    jldopen(joinpath(workspace(project), filename*".jld2"), true, true, true, IOStream) do file
        file[objectname] = object
    end
end

function rm(project, filename)
    path = joinpath(workspace(project), filename)
    if isdir(path)
        Base.rm(path, recursive=true)
    else
        Base.rm(path)
    end
end

#baseline_index(ant1, ant2) = ((ant1-1)*(512-(ant1-2)))÷2 + (ant2-ant1+1)
#Nant2Nbase(Nant) = (Nant*(Nant+1))÷2
#Nbase2Nant(Nbase) = round(Int, (sqrt(1+8Nbase)-1)/2)

end

