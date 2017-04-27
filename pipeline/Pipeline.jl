module Pipeline

#using LibHealpix
#using CasaCore.Measures
#using CasaCore.Tables
#using MLPFlagger
#using TTCal
#using BPJSpec
#
#using FileIO, JLD, NPZ
#using FITSIO, WCS
#
#using NLopt
#using Dierckx
#using Interpolations
#
#if nworkers() == 1
#    using PyPlot
#end

# Setup logging
#using ProgressMeter
#using Lumberjack
#if myid() == 1
#    remove_truck("console")
#    add_truck(LumberjackTruck(joinpath(logs, "$(now()).log")), "file-logger")
#    add_truck(LumberjackTruck(STDOUT, "info", Dict{Any,Any}(:is_colorized => true)), "console-output")
#end

include("Utility/Utility.jl") # interfaces to external utilities like dada2ms and wsclean
include("Common/Common.jl")   # common functionality needed for working with OVRO LWA datasets

include("Calibration/Calibration.jl")
include("MModes/MModes.jl")

#include("imaging.jl")
#include("fitrfi-mmodes.jl")
#include("getsun.jl")
#
##include("getmodel.jl")
#
#include("elevation-plot.jl")
#include("bisect.jl")
#include("interactive-baseline-flags.jl")
#include("inspect-integration.jl")
#include("experimental.jl")
#
## source detection and cleaning
#include("observation-matrix.jl")
#include("getpsf.jl")
#include("source-finding.jl")
#include("cleaning.jl")

end

