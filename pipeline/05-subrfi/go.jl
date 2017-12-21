#!/usr/bin/env julia-0.6.0

spw = parse(Int, ARGS[1])
dataset = ARGS[2]

addprocs(16)
include("Driver.jl")
Base.require(:Driver)
Driver.subrfi(spw, dataset)

