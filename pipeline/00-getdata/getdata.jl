#!/usr/bin/env julia-0.6.0

spw = parse(Int, ARGS[1])
dataset = ARGS[2]

addprocs(16)
@everywhere include("Driver.jl")
Driver.getdata(spw, dataset)

