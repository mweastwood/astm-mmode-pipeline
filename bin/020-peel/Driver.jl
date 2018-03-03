module Driver

using CasaCore.Measures
using JLD2
using ProgressMeter
using TTCal

include("../lib/Common.jl"); using .Common

function peel(spw, name)
    sky = readsky(joinpath(Common.workspace, "source-lists", "peeling-sky-model.json"))
    jldopen(joinpath(getdir(spw, name), "subrfi-impulsive-visibilities.jld2"), "r") do input_file
        metadata = input_file["metadata"]

        pool  = CachingPool(workers())
        queue = collect(1:Ntime(metadata))

        lck = ReentrantLock()
        prg = Progress(length(queue))
        increment() = (lock(lck); next!(prg); unlock(lck))

        residuals = Dict(source.name => zeros(Ntime(metadata)) for source in sky.sources)
        jldopen(joinpath(getdir(spw, name), "peeled-visibilities.jld2"), "w") do output_file
            @sync for worker in workers()
                @async while length(queue) > 0
                    index = pop!(queue)
                    raw_data = input_file[o6d(index)]
                    peeled_data, _residuals = remotecall_fetch(do_the_work, pool, spw, name,
                                                               raw_data, metadata, index, sky)
                    fill_in_residuals!(residuals, _residuals, index)
                    output_file[o6d(index)] = peeled_data
                    increment()
                end
            end
            output_file["metadata"]  = metadata
            output_file["residuals"] = residuals
        end
    end
end

function test(spw, name, integration)
    local output
    sky = readsky(joinpath(Common.workspace, "source-lists", "peeling-sky-model.json"))
    jldopen(joinpath(getdir(spw, name), "subrfi-impulsive-visibilities.jld2"), "r") do input_file
        metadata = input_file["metadata"]
        raw_data = input_file[o6d(integration)]

        println("# no source removal")
        output, residuals = _do_the_work(spw, name, raw_data, metadata, integration, sky,
                                         false, false, true)
        image(spw, name, integration, output, "/lustre/mweastwood/tmp/1-$integration", del=false)

        println("# only peeling")
        output, residuals = _do_the_work(spw, name, raw_data, metadata, integration, sky,
                                         true, false, true)
        image(spw, name, integration, output, "/lustre/mweastwood/tmp/2-$integration", del=false)

        #println("# full source removal")
        #output, residuals = _do_the_work(spw, name, raw_data, metadata, integration, sky,
        #                                 true, true, true)
        #image(spw, name, integration, output, "/lustre/mweastwood/tmp/3-$integration")
    end
    output
end

function fill_in_residuals!(residuals, _residuals, index)
    for name in keys(_residuals)
        residuals[name][index] = _residuals[name]
    end
end

function do_the_work(spw, name, data, metadata, time, sky)
    # call this function if you want an ordinary array
    ttcal, residuals = _do_the_work(spw, name, data, metadata, time, sky)
    ttcal_to_array(ttcal), residuals
end

function _do_the_work(spw, name, data, metadata, time, sky,
                      dopeeling=true, dosubtraction=true, istest=false)
    # call this function if you want the TTCal.Dataset
    ttcal = array_to_ttcal(data, metadata, time)
    residuals = do_the_source_removal!(spw, ttcal, sky, dopeeling, dosubtraction, istest)
    ttcal, residuals
end

function do_the_source_removal!(spw, dataset, sky, dopeeling, dosubtraction, istest)
    frame = ReferenceFrame(dataset.metadata)
    filter!(sky.sources) do source
        TTCal.isabovehorizon(frame, source)
    end
    measure_sky!(sky, dataset)
    bright, medium, faint = partition(spw, dataset.metadata, sky)
    istest && (print("1: "); foreach(s->print(s.name, ", "), bright.sources); println())
    istest && (print("2: "); foreach(s->print(s.name, ", "), medium.sources); println())
    istest && (print("3: "); foreach(s->print(s.name, ", "),  faint.sources); println())

    # peel bright sources
    if dopeeling
        subtract!(dataset, medium)
        calibrations = peel!(dataset, bright)
        add!(dataset, medium)

        # check to see if peeled sources were actually peeled
        #for (source, calibration) in zip(bright.sources, calibrations)
        #    model = genvis(dataset.metadata, TTCal.ConstantBeam(), source, polarization=TTCal.Dual)
        #    flux  = TTCal.getflux(model, source).I
        #    TTCal.corrupt!(model, calibration)
        #    flux′ = TTCal.getflux(model, source).I
        #    if abs(flux - flux′) > 0.1abs(flux)
        #        TTCal.add!(dataset, model)
        #        push!(medium.sources, source)
        #    end
        #end
    end

    if dosubtraction
        # subtract medium sources
        measure_sky!(medium, dataset)
        subtract!(dataset, medium)

        # subtract faint sources
        measure_sky!(faint, dataset)
        subtract!(dataset, faint)
    end

    # compute residuals
    residuals = Dict(source.name => TTCal.getflux(dataset, source).I for source in sky.sources)
    istest && @show residuals
    residuals
end

function measure_sky!(sky::TTCal.SkyModel, dataset)
    N = length(sky.sources)
    for idx = 1:N
        source = sky.sources[idx]
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

function add!(dataset, sky)
    if length(sky.sources) > 0
        model = genvis(dataset.metadata, TTCal.ConstantBeam(), sky, polarization=TTCal.Dual)
        TTCal.add!(dataset, model)
    end
end

function subtract!(dataset, sky)
    if length(sky.sources) > 0
        model = genvis(dataset.metadata, TTCal.ConstantBeam(), sky, polarization=TTCal.Dual)
        TTCal.subtract!(dataset, model)
    end
end

function peel!(dataset, sky)
    if length(sky.sources) > 0
        calibrations = TTCal.peel!(dataset, TTCal.ConstantBeam(), sky, quiet=true,
                                   collapse_frequency=false)
    else
        calibrations = TTCal.Calibration[]
    end
    calibrations
end

macro pick(name, category, elevation_threshold, flux_threshold)
    if category == :BRIGHT
        f = :categorize_bright
    elseif category == :FAINT
        f = :categorize_faint
    elseif category == :SPECIAL
        f = :categorize_special
    end
    quote
        if source.name == $name
            category, flux = $f(frame, metadata, source, $elevation_threshold, $flux_threshold)
            if category == :BRIGHT
                push!(bright, idx)
                push!(bright_flux, flux)
            elseif category == :MEDIUM
                push!(medium, idx)
                push!(medium_flux, flux)
            elseif category == :FAINT
                push!(faint, idx)
                push!(faint_flux, flux)
            elseif category == :SPECIAL
                push!(special, idx)
            end
        end
    end |> esc
end

function categorize_bright(frame, metadata, source, elevation_threshold, flux_threshold)
    flux = TTCal.total_flux.(source, metadata.frequencies) |> mean
    any_flux  = flux.I ≥ 30
    high_flux = flux.I ≥ flux_threshold
    high_elevation = TTCal.isabovehorizon(frame, source, threshold=deg2rad(elevation_threshold))
    if high_elevation && high_flux
        return :BRIGHT, flux.I
    elseif any_flux
        return :MEDIUM, flux.I
    else
        return :NOTHING, flux.I
    end
end

function categorize_faint(frame, metadata, source, elevation_threshold, flux_threshold)
    flux = TTCal.total_flux.(source, metadata.frequencies) |> mean
    any_flux  = flux.I ≥ 30
    high_flux = flux.I ≥ flux_threshold
    high_elevation = TTCal.isabovehorizon(frame, source, threshold=deg2rad(elevation_threshold))
    if high_elevation && high_flux
        return :MEDIUM, flux.I
    elseif any_flux
        return :FAINT, flux.I
    else
        return :NOTHING, flux.I
    end
end

function categorize_special(frame, metadata, source, elevation_threshold, flux_threshold)
    high_elevation = TTCal.isabovehorizon(frame, source, threshold=deg2rad(elevation_threshold))
    if high_elevation
        return :SPECIAL, 0
    else
        return :MEDIUM, 0
    end
end

function partition(spw, metadata, sky)
    # We have three categories for how sources are removed:
    #  1) peel them (for very bright sources)
    #  2) subtract them before peeling (for sources in the middle)
    #  3) subtract them after peeling (for faint sources)
    # The third category is important because reasonably bright sources can interfere with the
    # peeling process if the flux of the two sources is comparable. For example, Cas A near the
    # horizon can create problems for trying to peel Vir A.
    bright = Int[]
    medium = Int[]
    faint  = Int[]
    special = Int[]
    bright_flux = Float64[]
    medium_flux = Float64[]
    faint_flux  = Float64[]
    frame = ReferenceFrame(metadata)
    N = length(sky.sources)
    for idx = 1:N
        source = sky.sources[idx]
        if spw == 18
            #      name    | category | elev | flux
            # -------------------------------------
            @pick "Cyg A"     BRIGHT     10    1000
            @pick "Cas A"     BRIGHT     10    1000
            @pick "Vir A"     BRIGHT     30    1000
            @pick "Tau A"     BRIGHT     30    1000
            @pick "Her A"      FAINT     30     500
            @pick "Hya A"      FAINT     60     500
            @pick "Per B"      FAINT     60     500
            @pick "3C 353"     FAINT     60     500
            @pick "Sun"       BRIGHT     15       0
        end
    end

    # Upgrade sources between categories if they are brighter than the faintest source in the above
    # category.
    if length(bright_flux) > 0
        move = medium_flux .> minimum(bright_flux)
        append!(bright,      medium[move])
        append!(bright_flux, medium_flux[move])
        medium      = medium[.!move]
        medium_flux = medium_flux[.!move]
    end

    if length(medium_flux) > 0
        move = faint_flux .> minimum(medium_flux)
        append!(medium,      faint[move])
        append!(medium_flux, faint_flux[move])
        faint      = faint[.!move]
        faint_flux = faint_flux[.!move]
    end

    # Downgrade bright sources that are much fainter than the brightest source (this can cause
    # problems for peeling).
    if length(bright_flux) > 0
        move = 10 .* bright_flux .< maximum(bright_flux)
        append!(medium,      bright[move])
        append!(medium_flux, bright_flux[move])
        bright      = bright[.!move]
        bright_flux = bright_flux[.!move]
    end

    # Sort the bright sources in order of decreasing flux (this will determine the order in which
    # they are peeled).
    order = sortperm(bright_flux, rev=true)
    bright      = bright[order]
    bright_flux = bright_flux[order]

    bright_sky = TTCal.SkyModel(sky.sources[[special; bright]])
    medium_sky = TTCal.SkyModel(sky.sources[medium])
    faint_sky  = TTCal.SkyModel(sky.sources[faint])
    bright_sky, medium_sky, faint_sky
end

end

