#!/usr/bin/env julia-0.6.0

spw = parse(Int, ARGS[1])
dataset = ARGS[2]

addprocs([("astm05", 1), ("astm06", 1), ("astm07", 1),
          ("astm08", 1), ("astm09", 1), ("astm10", 1), ("astm11", 1),
          ("astm12", 1), ("astm13", 1)], topology=:master_slave)
include("Driver.jl")
Base.require(:Driver)
Driver.tikhonov(spw, dataset)

