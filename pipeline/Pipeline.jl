module Pipeline

using LibHealpix
using CasaCore.Measures
using CasaCore.Tables
using MLPFlagger
using TTCal
using BPJSpec

using FileIO, JLD, NPZ
using FITSIO, WCS

using NLopt
using Dierckx
#using Interpolations

if nworkers() == 1
    using PyPlot
end

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

baseline_index(ant1, ant2) = ((ant1-1)*(512-(ant1-2)))÷2 + (ant2-ant1+1)
Nant2Nbase(Nant) = (Nant*(Nant+1))÷2
Nbase2Nant(Nbase) = round(Int, (sqrt(1+8Nbase)-1)/2)

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

include("working-with-source-models.jl")

include("getmeta.jl")
include("getdata.jl")
include("flag.jl")
include("sawtooth.jl")
include("calibrate.jl")
include("imaging.jl")

include("fitrfi.jl")
include("fitrfi-special.jl")
include("fitrfi-mmodes.jl")
include("subrfi.jl")

include("peeling.jl")
include("getsun.jl")

# m-mode analysis
include("folddata.jl")
include("getmmodes.jl")
include("getalm.jl")
#include("getmodel.jl")
include("makemap.jl")

include("bisect.jl")
include("interactive-baseline-flags.jl")
include("inspect-integration.jl")
include("experimental.jl")

#include("getsun.jl")
#include("getdata_experimental.jl")
#include("compress.jl")
#include("folddata.jl")
#include("divide_and_image.jl")
#
#include("makemovie.jl")
#include("integrate.jl")
#include("fitrfi.jl")
#include("makecurves.jl")
#include("postprocess.jl")
##include("getsubresiduals.jl")
#include("fitbeam.jl")
#
## m-mode analysis
#include("gettransfermatrix.jl")
#include("getmodel.jl")
#include("makemap.jl")
#
## post-processing
#include("getpsf.jl")
##include("residualsvd.jl")
##include("imagesvd.jl")
##include("reconstruct.jl")
#
#
## cleaning
#include("cleaningregions.jl")
##include("cleaning.jl")
#
## testing
#include("getcyg.jl")
#include("getrfi.jl")
#
#include("flags.jl")
#include("getcal.jl")
#include("ionosphere.jl") # for Esayas

end

