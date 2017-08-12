module Cleaning

using JLD
using ProgressMeter
using CasaCore.Measures
using LibHealpix
using TTCal
using BPJSpec
using NLopt
import GSL
using ..Common
import ..MModes

#include("fix-flux-scale.jl")
#include("register.jl")

include("getpsf.jl")
include("clean.jl")

#include("clean-worker.jl")
#include("clean.jl")
#include("postage-stamp.jl")

#include("clean-worker.jl")

end

