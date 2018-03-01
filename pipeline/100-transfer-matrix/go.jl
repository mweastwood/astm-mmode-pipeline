#!/usr/bin/env julia-0.6.0

spw = parse(Int, ARGS[1])
dataset = ARGS[2]

N = 4
addprocs([("astm05", N), ("astm06", N), ("astm07", N),
          ("astm08", N), ("astm09", N), ("astm10", N), ("astm11", N),
          ("astm12", N), ("astm13", N)])
include("Driver.jl")
Base.require(:Driver)
Driver.transfermatrix(spw, dataset)

