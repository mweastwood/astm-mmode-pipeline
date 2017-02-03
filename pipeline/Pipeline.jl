module Pipeline

using LibHealpix
using CasaCore.Measures
using CasaCore.Tables
using MLPFlagger
using TTCal
using BPJSpec

using FileIO, JLD
using FITSIO, WCS

using NLopt # for fitting the beam and RFI
#using Interpolations

const tempdir = "/dev/shm/mweastwood"
const basedir = joinpath(dirname(@__FILE__), "..")
const workspace = joinpath(basedir, "workspace")
const sourcelists = joinpath(workspace, "source-lists")
const logs = joinpath(basedir, "logs")

isdir(tempdir) || mkdir(tempdir)
if myid() == 1
    isdir(workspace) || mkdir(workspace)
    isdir(sourcelists) || mkdir(sourcelists)
    isdir(logs) || mkdir(logs)
end

function getdir(spw)
    dir = joinpath(workspace, @sprintf("spw%02d", spw))
    isdir(dir) || mkdir(dir)
    dir
end

baseline_index(ant1, ant2) = div((ant1-1)*(512-(ant1-2)), 2) + (ant2-ant1+1)

# Setup logging
using ProgressMeter
using Lumberjack
if myid() == 1
    remove_truck("console")
    add_truck(LumberjackTruck(joinpath(logs, "$(now()).log")), "file-logger")
    add_truck(LumberjackTruck(STDOUT, "info", Dict{Any,Any}(:is_colorized => true)), "console-output")
end

function cleanup()
    # delete all files in /dev/shm/mweastwood
    dir = "/dev/shm/mweastwood"
    if myid() != 1 && isdir(dir)
        files = readdir(dir)
        if length(files) > 0
            for file in files
                rm(joinpath(dir, file), recursive=true)
            end
        end
    end
end

include("dada2ms.jl")
include("wsclean.jl")

include("flags.jl")
include("getmeta.jl")
include("getcal.jl")
include("getsun.jl")
include("getdata.jl")
include("getdata_experimental.jl")
include("compress.jl")
include("folddata.jl")
include("divide_and_image.jl")

include("makemovie.jl")
include("integrate.jl")
include("fitrfi.jl")
include("makecurves.jl")
include("postprocess.jl")
#include("getsubresiduals.jl")
include("fitbeam.jl")

# m-mode analysis
include("getmmodes.jl")
include("gettransfermatrix.jl")
include("getalm.jl")
include("getmodel.jl")
include("makemap.jl")

# post-processing
include("getpsf.jl")
#include("residualsvd.jl")
#include("imagesvd.jl")
#include("reconstruct.jl")


# cleaning
include("cleaningregions.jl")
#include("cleaning.jl")

# testing
include("getcyg.jl")
include("getrfi.jl")

end

