module Driver

using JLD2
using ProgressMeter
using TTCal

include("../../pipeline/lib/Common.jl");  using .Common

function transpose(spws, name)
    jldopen(joinpath(Common.workspace, "auto-correlations-$name.jld2"), "w") do file
        prg = Progress(256)
        for ant = 1:256
            metadata, xx, yy = read_autos(spws, name, ant)
            file[@sprintf("%03d", 2ant-1)] = xx
            file[@sprintf("%03d", 2ant-0)] = yy
            if ant == 1
                file["metadata"] = metadata
            end
            next!(prg)
        end
    end
end

function read_autos(spws::AbstractVector, name, ant)
    metadata, xx, yy = read_autos(spws[1], name, ant)
    for spw in spws[2:end]
        _metadata, _xx, _yy = read_autos(spw, name, ant)
        xx = cat(1, xx, _xx)
        yy = cat(1, yy, _yy)
        TTCal.merge!(metadata, _metadata, axis=:frequency)
    end
    metadata, xx, yy
end

function read_autos(spw::Integer, name, ant)
    local metadata, xx, yy
    jldopen(joinpath(getdir(spw, name), "auto-correlations.jld2"), "r") do file
        xx = file[@sprintf("%03d", 2ant-1)]
        yy = file[@sprintf("%03d", 2ant-0)]
        metadata = file["metadata"]
    end
    metadata, xx, yy
end

end

