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
    sky = readsky(joinpath(Common.workspace, "source-lists", "calibration-sky-model.json"))

    local output
    jldopen(joinpath(getdir(spw, name), "calibrated-visibilities.jld2"), "r") do input_file
        metadata = input_file["metadata"]

        #raw_data = input_file[o6d(1650)]
        #@time output = do_the_work(spw, name, raw_data, metadata, 1650, sky)
        #@time image(spw, name, 1650, output)

        pool  = CachingPool(workers())
        queue = collect(1:Ntime(metadata))

        lck = ReentrantLock()
        prg = Progress(length(queue))
        increment() = (lock(lck); next!(prg); unlock(lck))

        jldopen(joinpath(getdir(spw, name), "peeled-visibilities.jld2"), "w") do output_file
            @sync for worker in workers()
                @async while length(queue) > 0
                    index = pop!(queue)
                    raw_data = input_file[o6d(index)]
                    peeled_data = remotecall_fetch(do_the_work, pool, spw, name, raw_data,
                                                   metadata, index, sky)
                    output_file[o6d(index)] = peeled_data
                    increment()
                end
            end
            output_file["metadata"] = metadata
        end
    end
    output
end

function do_the_work(spw, name, data, metadata, time, sky)
    ttcal = array_to_ttcal(data, metadata, time)
    Common.flag!(spw, name, ttcal)
    do_the_source_removal!(spw, ttcal, sky)
    #ttcal_to_array(ttcal)
end

function do_the_source_removal!(spw, dataset, sky)
    frame = ReferenceFrame(dataset.metadata)
    filter!(sky.sources) do source
        TTCal.isabovehorizon(frame, source)
    end
    measure_sky!(sky, dataset)
    bright, medium, faint = partition(spw, dataset.metadata, sky)
    #@show bright medium faint
    peel!(dataset, bright)
    #subtract!(dataset, sky)
    dataset
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

function image(spw, name, integration, input)
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
    wsclean(ms.path)
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
            # -------------------------------------------------------------------------
            @pick "Cyg A"     BRIGHT     10    1000
            @pick "Cas A"     BRIGHT     10    1000
            @pick "Vir A"      FAINT     30    1000
            @pick "Tau A"      FAINT     30    1000
            @pick "Her A"      FAINT     30     500
            @pick "Hya A"      FAINT     60     500
            @pick "Per B"      FAINT     60     500
            @pick "3C 353"     FAINT     60     500
        end
    end
    bright_sky = TTCal.SkyModel(sky.sources[bright])
    medium_sky = TTCal.SkyModel(sky.sources[medium])
    faint_sky  = TTCal.SkyModel(sky.sources[faint])
    bright_sky, medium_sky, faint_sky
end


#function pick_sources_for_peeling_and_subtraction(spw, meta, sources, I, Q, directions, istest=false)
#    # We have three categories for how sources are removed:
#    #  1) peel them (for very bright sources)
#    #  2) subtract them after peeling (for faint sources)
#    #  3) subtract them before peeling (for sources in the middle)
#    # The third category is important because reasonably bright sources can interfere with the
#    # peeling process if the flux of the two sources is comparable. For example, Cas A near the
#    # horizon can create problems for trying to peel Vir A.
#    to_peel = Int[]
#    to_sub_faint  = Int[]
#    to_sub_bright = Int[]
#    to_fit_with_shapelets = Int[]
#    frame = TTCal.reference_frame(meta)
#    for idx = 1:length(sources)
#        source = sources[idx]
#        TTCal.isabovehorizon(frame, source) || continue
#        if spw == 18
#            #   Removal Technique    |   Name   | elev-e | elev-w | flux-hi | flux-lo |
#            # -------------------------------------------------------------------------
#            @pick_for_peeling          "Cyg A"     10       10       1000        30
#            @pick_for_peeling          "Cas A"     10       10       1000        30
#            #@pick_for_peeling          "Vir A"     30       30       1000        30
#            #@pick_for_peeling          "Tau A"     30       30       1000        30
#            #@pick_for_subtraction      "Her A"     30       30        500        30
#            #@pick_for_subtraction      "Hya A"     60       60        500        30
#            #@pick_for_subtraction      "Per B"     60       60        500        30
#            #@pick_for_subtraction      "3C 353"    60       60        500        30
#            #@pick_for_peeling          "Sun"       15       15          0         0
#        end
#    end
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

