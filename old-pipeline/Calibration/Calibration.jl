module Calibration

using JLD2
using ProgressMeter
using NLopt
using CasaCore.Measures
using CasaCore.Tables
using TTCal
using ..Utility
using ..Common

include("working-with-source-models.jl")
include("getdata.jl")
#include("flag.jl")
#include("sawtooth.jl")
#include("calibrate.jl")
#include("fitrfi.jl")
#include("subrfi.jl")
#include("addrfi.jl")
#include("peeling.jl")
#include("fitbeam.jl")
#include("removed-source-visibilities.jl")
#
#include("getsun.jl")
#include("rm-sun.jl")

end

