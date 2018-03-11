#!/usr/bin/env julia-0.6

using ArgParse
using JLD2

include("../lib/Matrices.jl")
include("../lib/Datasets.jl")
include("../lib/CreateMeasurementSet.jl")

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table s begin
        "input"
            help = "path to the dataset"
            arg_type = String
            required = true
        "output"
            help = "path to the output measurement set"
            arg_type = String
            required = true
        "integration"
            help = "the integration number to extract"
            arg_type = Int
            required = true
    end
    return parse_args(s)
end

o6d(i) = @sprintf("%06d", i)

function main()
    args = parse_commandline()
    input = args["input"]
    output = args["output"]
    integration = args["integration"]

    visibilities = Matrices.Visibilities(input)
    data = visibilities[integration]

    metadata_path = joinpath(dirname(input), "metadata.jld2")
    metadata = jldopen(metadata_path, false, false, false, IOStream) do file
        file["metadata"]
    end

    dataset = Datasets.array_to_ttcal(data, metadata, integration)
    CreateMeasurementSet.create(dataset, output)

    println("Try imaging the measurement set with:")
    name = joinpath(dirname(output), "test")
    println("\$ wsclean -size 2048 2048 -scale 0.0625 -weight uniform -name $name $output")
    println("Or inspect the visibilities with `casaplotms` and `casabrowser.`")
end
main()

