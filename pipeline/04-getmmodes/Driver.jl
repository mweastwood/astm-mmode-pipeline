module Driver

using JLD2
using ProgressMeter
using TTCal
using BPJSpec

include("../lib/Common.jl"); using .Common

function getmmodes(spw, name)
    path =  getdir(spw, name)
    meta = getmeta(spw, name)
    jldopen(joinpath(path, "folded-visibilities.jld2"), "r") do input_file
        ttcal_metadata   = input_file["metadata"]
        bpjspec_metadata = BPJSpec.from_ttcal(ttcal_metadata)



        prg = Progress(length(frequencies))
        for index = 1:length(frequencies)
            getmmodes(spw, name, input_file[@sprintf("%06d", index)], meta, frequencies, times)
            next!(prg)
        end
    end
end


end

