module Calibration

using JLD
using ProgressMeter
using CasaCore.Measures
using CasaCore.Tables
using TTCal
using ..Utility
using ..Common

include("working-with-source-models.jl")
include("getdata.jl")
include("flag.jl")
include("sawtooth.jl")
include("calibrate.jl")
include("fitrfi.jl")
include("subrfi.jl")
include("peeling.jl")

end

