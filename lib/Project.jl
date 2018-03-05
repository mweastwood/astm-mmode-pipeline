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

#baseline_index(ant1, ant2) = ((ant1-1)*(512-(ant1-2)))÷2 + (ant2-ant1+1)
#Nant2Nbase(Nant) = (Nant*(Nant+1))÷2
#Nbase2Nant(Nbase) = round(Int, (sqrt(1+8Nbase)-1)/2)

end

