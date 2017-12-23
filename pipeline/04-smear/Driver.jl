module Driver

using CasaCore.Measures
using FileIO, JLD2
using ProgressMeter
using TTCal
using Unitful

include("../lib/Common.jl"); using .Common

function smear(spw, name)
    dataset = _smear(spw, name)
    jldopen(joinpath(getdir(spw, name), "smeared-visibilities.jld2"), "w") do file
        file["dataset"] = dataset
    end
    #dataset = load(joinpath(getdir(spw, name), "smeared-visibilities.jld2"), "dataset")
    residuals, coherencies = peel(spw, name, dataset, 3)
    jldopen(joinpath(getdir(spw, name), "smeared-visibilities.jld2"), "r+") do file
        file["residuals"]   = residuals
        file["coherencies"] = ttcal_to_array.(coherencies)
    end
    compute_images(spw, name, dataset, residuals, coherencies)
end

function _smear(spw, name)
    local accumulation, metadata
    jldopen(joinpath(getdir(spw, name), "calibrated-visibilities.jld2"), "r") do file
        metadata = file["metadata"]
        accumulation = zeros(Complex128, 2, Nfreq(metadata), Nbase(metadata))
        prg = Progress(Ntime(metadata))
        for index = 1:Ntime(metadata)
            data = file[o6d(index)]
            accumulation .+= data
            next!(prg)
        end
    end
    accumulation ./= Ntime(metadata) # convert from sum to mean
    dataset = array_to_ttcal(accumulation, metadata, 1)
    jldopen(joinpath(getdir(spw, name), "smeared-visibilities.jld2"), "w") do file
        file["dataset"] = dataset
    end
    dataset
end

function peel(spw, name, dataset, N)
    Common.flag!(spw, name, dataset)
    zenith = Direction(dir"AZEL", 0u"°", 90u"°")
    flat   = TTCal.PowerLaw(1, 0, 0, 0, 10u"MHz", [0.0])
    dummy  = TTCal.Source("dummy", TTCal.Point(zenith, flat))
    sky = TTCal.SkyModel(fill(dummy, N))
    residuals = deepcopy(dataset)
    calibrations = TTCal.peel!(residuals, TTCal.ConstantBeam(), sky)
    coherencies  = compute_coherencies(dataset.metadata, sky, calibrations)
    residuals, coherencies
end

function compute_coherencies(metadata, sky, calibrations)
    function f(s, c)
        coherency = genvis(metadata, TTCal.ConstantBeam(), s, polarization=TTCal.Dual)
        TTCal.corrupt!(coherency, c)
    end
    f.(sky.sources, calibrations)
end

function compute_images(spw, name, original, residuals, coherencies)
    dir = getdir(spw, name)
    image(spw, name, 1, original,  joinpath(dir, "smeared-visibilities"))
    image(spw, name, 1, residuals, joinpath(dir, "smeared-visibilities-residuals"))
    for (idx, coherency) in enumerate(coherencies)
        image(spw, name, 1, coherency, joinpath(dir, "smeared-visibilities-component-$idx"))
    end
end

end

