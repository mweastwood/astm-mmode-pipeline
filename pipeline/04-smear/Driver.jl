module Driver

using CasaCore.Measures
using CasaCore.Tables
using FileIO, JLD2
using ProgressMeter
using TTCal
using Unitful

include("../lib/Common.jl");  using .Common
include("../lib/DADA2MS.jl"); using .DADA2MS
include("../lib/WSClean.jl"); using .WSClean

function smear(spw, name)
    dataset = _smear(spw, name)
    jldopen(joinpath(getdir(spw, name), "smeared-visibilities.jld2"), "w") do file
        file["dataset"] = dataset
    end
    #dataset = load(joinpath(getdir(spw, name), "smeared-visibilities.jld2"), "dataset")
    residuals, coherencies = peel(spw, name, dataset, 2)
    jldopen(joinpath(getdir(spw, name), "smeared-visibilities.jld2"), "r+") do file
        file["residuals"]   = residuals
        file["coherencies"] = coherencies
    end
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
    calibrations = TTCal.peel!(deepcopy(dataset), TTCal.ConstantBeam(), sky)
    coherencies  = compute_coherencies(dataset.metadata, sky, calibrations)
    dataset, coherencies
end

function compute_coherencies(metadata, sky, calibrations)
    function f(s, c)
        coherency = genvis(metadata, TTCal.ConstantBeam(), s, polarization=TTCal.Dual)
        TTCal.corrupt!(coherency, c)
    end
    f.(sky.sources, calibrations)
end

function compute_images(original, residuals, coherencies)
    image(spw, name, original,  "smeared-visibilities")
    image(spw, name, residuals, "smeared-visibilities-residuals")
    N = length(coherencies)
    for (idx, coherency) in enumerate(coherencies)
        image(spw, name, coherency, "smeared-visibilities-component-$idx")
    end
end

function image(spw, name, input, filename)
    dadas = Common.listdadas(spw, name)
    dada  = dadas[1]
    ms = dada2ms(spw, dada, name)
    metadata = TTCal.Metadata(ms)
    output = TTCal.Dataset(metadata, polarization=TTCal.Dual)
    for idx = 1:Nfreq(input)
        jdx = find(metadata.frequencies .== input.metadata.frequencies[idx])[1]
        input_vis  =  input[idx, 1]
        output_vis = output[jdx, 1]
        for ant1 = 1:Nant(input), ant2=ant1:Nant(input)
            output_vis[ant1, ant2] = input_vis[ant1, ant2]
        end
    end
    TTCal.write(ms, output, column="CORRECTED_DATA")
    Tables.close(ms)
    wsclean(ms.path, joinpath(getdir(spw, name), filename))
    Tables.delete(ms)
end

end

