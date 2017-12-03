module Driver

using JLD2
using ProgressMeter
using TTCal
using BPJSpec

include("../lib/Common.jl"); using .Common

function getmmodes(spw, name)
    path =  getdir(spw, name)
    mmax = (6628-1) ÷ 2
    jldopen(joinpath(path, "folded-visibilities.jld2"), "r") do input_file
        ttcal_metadata   = input_file["metadata"]
        bpjspec_metadata = BPJSpec.from_ttcal(ttcal_metadata)
        mmodes = MModes(joinpath(path, "m-modes"), bpjspec_metadata, mmax)
        prg = Progress(Nfreq(ttcal_metadata))
        for index = 1:Nfreq(ttcal_metadata)
            _getmmodes(mmodes, input_file[@sprintf("%06d", index)], index)
            next!(prg)
        end
    end
end

function _getmmodes(mmodes, array, index)
    # put time on the fast axis
    transposed_array = permutedims(array, (2, 1))
    # compute the m-modes
    BPJSpec.compute!(mmodes, transposed_array, mmodes.metadata.frequencies[index])
end

end

