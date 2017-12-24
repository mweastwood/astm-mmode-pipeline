module Driver

using CasaCore.Measures
using FileIO, JLD2
using ProgressMeter
using TTCal
using Unitful

include("../lib/Common.jl"); using .Common

macro fitrfi(integration, args...)
    output = quote
        _fitrfi(spw, name, input_file, metadata, $integration, $args)
    end
    esc(output)
end

function fitrfi(spw, name)
    jldopen(joinpath(getdir(spw, name), "rfiremoved-visibilities.jld2"), "r") do input_file
        metadata = input_file["metadata"]
        @fitrfi 3837 1 "Cas A" "Tau A" "Cyg A"
    end
end

function _fitrfi(spw, name, input_file, metadata, integration, args)
    sky = construct_sky(args)
    raw_data = input_file[o6d(integration)]
    dataset = array_to_ttcal(raw_data, metadata, integration)
    residuals, coherencies = peel(spw, name, dataset, sky)
    compute_images(spw, name, integration, dataset, residuals, coherencies)
end

function construct_sky(args)
    sources = TTCal.Source[]
    sky = readsky(joinpath(Common.workspace, "source-lists", "peeling-sky-model.json"))
    names = getfield.(sky.sources, :name)
    for arg in args
        if arg in names
            append!(sources, sky.sources[names .== arg])
        elseif arg isa Integer
            append!(sources, fill(dummy(), arg))
        else
            error("unknown source")
        end
    end
    (print("Sky: "); foreach(s->print(s.name, ", "), sources); println())
    TTCal.SkyModel(sources)
end

function dummy()
    zenith = Direction(dir"AZEL", 0u"°", 90u"°")
    flat   = TTCal.PowerLaw(1, 0, 0, 0, 10u"MHz", [0.0])
    TTCal.Source("dummy", TTCal.Point(zenith, flat))
end

function measure_sky!(sky::TTCal.SkyModel, dataset)
    N = length(sky.sources)
    for idx = 1:N
        source = sky.sources[idx]
        source.name == "dummy" && continue
        # fit for position
        source = fitvis(dataset, source)
        # fit for flux
        measured_spectrum = getspec(dataset, source)
        model_spectrum = TTCal.total_flux.(source, dataset.metadata.frequencies)
        scale = mean(a.I / b.I for (a, b) in zip(measured_spectrum, model_spectrum))
        source = scale*source
        sky.sources[idx] = source
    end
end

function peel(spw, name, dataset, sky)
    Common.flag!(spw, name, dataset)
    measure_sky!(sky, dataset)
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

function compute_images(spw, name, integration, original, residuals, coherencies)
    dir = getdir(spw, name)
    files = readdir(dir)
    for file in files
        if startswith(file, "fitrfi-$integration")
            rm(joinpath(dir, file))
        end
    end
    image(spw, name, integration, original,  joinpath(dir, "fitrfi-$integration-start"))
    image(spw, name, integration, residuals, joinpath(dir, "fitrfi-$integration-stop"))
    for (idx, coherency) in enumerate(coherencies)
        image(spw, name, integration, coherency, joinpath(dir, "fitrfi-$integration-$idx"))
    end
end

end

