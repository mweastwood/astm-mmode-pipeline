module Driver

using CasaCore.Measures
using FileIO, JLD2
using ProgressMeter
using TTCal
using Unitful

include("../lib/Common.jl"); using .Common

macro fitrfi(integration, sources, options...)
    sym = gensym()
    options = Dict{Symbol, Any}(eval(current_module(), option) for option in options)
    select = get(options, :select, 1)
    pol    = get(options, :pol, TTCal.Dual)
    istest = get(options, :istest, true)
    output = quote
        $sym = _fitrfi(spw, name, input_file, metadata, $integration, $sources,
                       $select, $pol, $istest)
        push!(coherencies, $sym)
    end
    esc(output)
end

function fitrfi(spw, name)
    dir = getdir(spw, name)
    jldopen(joinpath(dir, "subrfi-stationary-visibilities.jld2"), "r") do input_file
        metadata = input_file["metadata"]
        coherencies = Array{Complex128, 3}[]

        @fitrfi 3664 ("Cas A", 1, "Cyg A", "Tau A") :select=>2 :istest=>false
        #@fitrfi 3664 ("Cas A", 1, "Cyg A", "Tau A") :select=>2 :pol=>TTCal.YY :istest=>false

        jldopen(joinpath(dir, "fitrfi-impulsive-coherencies.jld2"), "w") do output_file
            output_file["coherencies"] = coherencies
        end
    end
end

function _fitrfi(spw, name, input_file, metadata, integration, sources, select, pol, istest)
    sky = construct_sky(sources)
    raw_data = input_file[o6d(integration)]
    dataset = array_to_ttcal(raw_data, metadata, integration, pol)
    residuals, coherencies = peel(spw, name, dataset, sky)
    istest && compute_images(spw, name, integration, dataset, residuals, coherencies)
    ttcal_to_array(coherencies[select])
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
    measure_sky!(sky, dataset)
    residuals = deepcopy(dataset)
    calibrations = TTCal.peel!(residuals, TTCal.ConstantBeam(), sky)
    coherencies  = compute_coherencies(dataset.metadata, sky, calibrations,
                                       TTCal.polarization(dataset))
    residuals, coherencies
end

function compute_coherencies(metadata, sky, calibrations, polarization)
    function f(s, c)
        coherency = genvis(metadata, TTCal.ConstantBeam(), s, polarization=polarization)
        TTCal.corrupt!(coherency, c)
    end
    f.(sky.sources, calibrations)
end

function compute_images(spw, name, integration, original, residuals, coherencies)
    dir = joinpath(getdir(spw, name), "fitrfi")
    isdir(dir) || mkdir(dir)
    files = readdir(dir)
    prefix = o6d(integration)
    for file in files
        if startswith(file, prefix)
            rm(joinpath(dir, file))
        end
    end
    image(spw, name, integration, original,  joinpath(dir, "$prefix-start"))
    image(spw, name, integration, residuals, joinpath(dir, "$prefix-stop"))
    for (idx, coherency) in enumerate(coherencies)
        image(spw, name, integration, coherency, joinpath(dir, "$prefix-$idx"))
    end
end

end

