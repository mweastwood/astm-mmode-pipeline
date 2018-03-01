#!/usr/bin/env julia-0.6.0

spw = parse(Int, ARGS[1])
dataset = ARGS[2]

N = 1
addprocs([("astm05", N), ("astm06", N), ("astm07", N),
          ("astm08", N), ("astm09", N), ("astm10", N), ("astm11", 3),
          ("astm12", N), ("astm13", N)], topology=:master_slave)
include("Driver.jl")
Base.require(:Driver)
Driver.average(spw, dataset)

