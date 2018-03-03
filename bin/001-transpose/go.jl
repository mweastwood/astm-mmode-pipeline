#!/usr/bin/env julia-0.6.0

spw = parse(Int, ARGS[1])
dataset = ARGS[2]

include("Driver.jl")
Driver.transpose_raw(spw, dataset)

