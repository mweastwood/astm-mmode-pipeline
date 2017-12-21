module Driver

using CasaCore.Measures
using CasaCore.Tables
using JLD2
using ProgressMeter
using TTCal

include("../lib/Common.jl");  using .Common
include("../lib/DADA2MS.jl"); using .DADA2MS
include("../lib/WSClean.jl"); using .WSClean

function peel(spw, name)
    sky = readsky(joinpath(Common.workspace, "source-lists", "peeling-sky-model.json"))
    jldopen(joinpath(getdir(spw, name), "rfiremoved-visibilities.jld2"), "r") do input_file
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
    jldopen(joinpath(getdir(spw, name), "calibrated-visibilities.jld2"), "r") do input_file
        metadata = input_file["metadata"]
        raw_data = input_file[o6d(integration)]

        println("# no source removal")
        output, residuals = _do_the_work(spw, name, raw_data, metadata, integration, sky,
                                         false, false, true)
        image(spw, name, integration, output, "/lustre/mweastwood/tmp/1-$integration")

        println("# only peeling")
        output, residuals = _do_the_work(spw, name, raw_data, metadata, integration, sky,
                                         true, false, true)
        image(spw, name, integration, output, "/lustre/mweastwood/tmp/2-$integration")

        println("# full source removal")
        output, residuals = _do_the_work(spw, name, raw_data, metadata, integration, sky,
                                         true, true, true)
        image(spw, name, integration, output, "/lustre/mweastwood/tmp/3-$integration")
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
    Common.flag!(spw, name, ttcal)
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
        peel!(dataset, bright)
        add!(dataset, medium)
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
    dataset
end

function subtract!(dataset, sky)
    if length(sky.sources) > 0
        model = genvis(dataset.metadata, TTCal.ConstantBeam(), sky, polarization=TTCal.Dual)
        TTCal.subtract!(dataset, model)
    end
    dataset
end

function peel!(dataset, sky)
    if length(sky.sources) > 0
        TTCal.peel!(dataset, TTCal.ConstantBeam(), sky)
    end
    dataset
end

function image(spw, name, integration, input, fits)
    dadas = Common.listdadas(spw, name)
    dada  = dadas[integration]
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
    wsclean(ms.path, fits)
    #Tables.open(ms)
    #Tables.delete(ms)
end

macro pick(name, category, elevation_threshold, flux_threshold)
    if category == :BRIGHT
        f = :categorize_bright
    else
        f = :categorize_faint
    end
    quote
        if source.name == $name
            category = $f(frame, metadata, source, $elevation_threshold, $flux_threshold)
            if category == :BRIGHT
                push!(bright, idx)
            elseif category == :MEDIUM
                push!(medium, idx)
            elseif category == :FAINT
                push!(faint, idx)
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
        return :BRIGHT
    elseif any_flux
        return :MEDIUM
    else
        return :NOTHING
    end
end

function categorize_faint(frame, metadata, source, elevation_threshold, flux_threshold)
    flux = TTCal.total_flux.(source, metadata.frequencies) |> mean
    any_flux  = flux.I ≥ 30
    high_flux = flux.I ≥ flux_threshold
    high_elevation = TTCal.isabovehorizon(frame, source, threshold=deg2rad(elevation_threshold))
    if high_elevation && high_flux
        return :MEDIUM
    elseif any_flux
        return :FAINT
    else
        return :NOTHING
    end
end

function partition(spw, metadata, sky)
    bright = Int[]
    medium = Int[]
    faint  = Int[]
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
    bright_sky = TTCal.SkyModel(sky.sources[bright])
    medium_sky = TTCal.SkyModel(sky.sources[medium])
    faint_sky  = TTCal.SkyModel(sky.sources[faint])
    bright_sky, medium_sky, faint_sky
end


#    # We have three categories for how sources are removed:
#    #  1) peel them (for very bright sources)
#    #  2) subtract them after peeling (for faint sources)
#    #  3) subtract them before peeling (for sources in the middle)
#    # The third category is important because reasonably bright sources can interfere with the
#    # peeling process if the flux of the two sources is comparable. For example, Cas A near the
#    # horizon can create problems for trying to peel Vir A.
#
#    # If a source we are trying to subtract has higher flux than a source we are trying to peel, we
#    # should probably be peeling that source.
#    move = zeros(Bool, length(to_sub_bright))
#    for idx in to_sub_bright
#        for jdx in to_peel
#            if I[idx] > I[jdx]
#                move[to_sub_bright .== idx] = true
#            end
#        end
#    end
#    to_peel = [to_peel; to_sub_bright[move]]
#    to_sub_bright = to_sub_bright[!move]
#
#    # If a source is much fainter than another source that is being peeled, it should be subtracted
#    # instead.
#    if length(to_peel) > 0
#        max_I = maximum(I[to_peel])
#        move = zeros(Bool, length(to_peel))
#        for idx in to_peel
#            if 10I[idx] < max_I
#                move[to_peel .== idx] = true
#            end
#        end
#        to_sub_bright = [to_sub_bright; to_peel[move]]
#        to_peel = to_peel[!move]
#    end
#
#    fluxes = I[to_peel]
#    perm = sortperm(fluxes, rev=true)
#    istest && @show I
#    istest && @show fluxes[perm]
#    to_peel[perm], to_sub_bright, to_sub_faint, to_fit_with_shapelets
#end

end

