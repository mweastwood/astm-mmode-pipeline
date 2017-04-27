module Calibration

using CasaCore.Measures
using TTCal

include("working-with-source-models.jl")
include("getdata.jl")
include("flag.jl")
include("sawtooth.jl")
include("calibrate.jl")
include("fitrfi.jl")
include("fitrfi-special.jl")
include("subrfi.jl")
include("peeling.jl")

end

