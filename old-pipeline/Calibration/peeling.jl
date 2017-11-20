function peel(spw, dataset, target)
    dir = getdir(spw)
    times, data, flags = load(joinpath(dir, "$target-$dataset-visibilities.jld"),
                              "times", "data", "flags")
    peel(spw, dataset, target, times, data, flags)
end

immutable PeelingData
    time :: Float64
    sources :: Vector{Source}
    I :: Vector{Float64}
    Q :: Vector{Float64}
    directions :: Vector{Direction}
    calibrations :: Vector{GainCalibration}
    to_peel :: Vector{Int}
    to_sub_bright :: Vector{Int}
    to_sub_faint :: Vector{Int}
    to_fit_with_shapelets :: Vector{Int}
end

function peel(spw, dataset, target, times, data, flags;
              istest=false, dopeeling=true, dosubtraction=true)
    Ntime = length(times)
    idx = 1
    nextidx() = (myidx = idx; idx += 1; myidx)

    p = Progress(Ntime)
    l = ReentrantLock()
    increment_progress() = (lock(l); next!(p); unlock(l))

    peeling_data = Vector{PeelingData}(Ntime)
    @sync for worker in workers()
        @async begin
            input  = RemoteChannel()
            output = RemoteChannel()
            remotecall(peel_worker_loop, worker, spw, input, output, dataset,
                       istest, dopeeling, dosubtraction)
            while true
                myidx = nextidx()
                myidx ≤ Ntime || break
                put!(input, (myidx, times[myidx], data[:, :, myidx], flags[:, myidx]))
                data[:, :, myidx], flags[:, myidx], peeling_data[myidx] = take!(output)
                increment_progress()
            end
            close(input)
            close(output)
        end
    end

    if !istest
        dir = getdir(spw)
        target = replace(target, "calibrated", "peeled")
        target = replace(target, "rfi-subtracted-", "")
        target = replace(target, "twice-", "")
        output_file = joinpath(dir, "$target-$dataset-visibilities.jld")
        isfile(output_file) && rm(output_file)
        save(output_file, "times", times, "data", data, "flags", flags,
             "peeling-data", peeling_data, compress=true)
    end

    peeling_data
end

function peel_worker_loop(spw, input, output, dataset, istest, dopeeling, dosubtraction)
    dir = getdir(spw)
    meta = getmeta(spw, dataset)
    meta.channels = meta.channels[55:55]
    sources = readsources(joinpath(dirname(@__FILE__), "..", "..", "workspace", "source-lists",
                                   "getdata-sources.json"))
    while true
        try
            integration, time, data, flags = take!(input)
            peeling_data = peel_do_the_work(time, data, flags, spw, dir, meta, sources,
                                            dataset, integration, istest, dopeeling, dosubtraction)
            put!(output, (data, flags, peeling_data))
        catch exception
            if isa(exception, RemoteException) || isa(exception, InvalidStateException)
                # If this is a remote worker, we will see a RemoteException when the channel is
                # closed. However, if this is the master process (ie. we're running without any
                # workers) then this will be an InvalidStateException. This is kind of messy...
                break
            else
                println(exception)
                rethrow(exception)
            end
        end
    end
end

function peel_do_the_work(time, data, flags, spw, dir, meta, sources,
                          dataset, integration, istest, dopeeling=true, dosubtraction=true)
    xx = data[1, :]
    yy = data[2, :]

    meta.time = Epoch(epoch"UTC", time*seconds)
    meta.phase_center = Direction(dir"AZEL", 0degrees, 90degrees)

    # flag the auto correlations
    for ant = 1:Nant(meta)
        α = baseline_index(ant, ant)
        flags[α] = true
    end

    xx, yy, peeling_data = rm_sources(time, flags, xx, yy, spw, meta, sources,
                                      dataset, integration, istest, dopeeling, dosubtraction)

    data[1, :] = xx
    data[2, :] = yy

    peeling_data
end

function rm_sources(time, flags, xx, yy, spw, meta, sources,
                    dataset, integration, istest, dopeeling, dosubtraction)
    prototype_peeling_flags(spw, flags)
    visibilities = Visibilities(Nbase(meta), 1)
    for α = 1:Nbase(meta)
        visibilities.data[α, 1] = JonesMatrix(xx[α], 0, 0, yy[α])
        visibilities.flags[α, 1] = flags[α]
    end
    TTCal.flag_short_baselines!(visibilities, meta, 15.0)

    original_sources = deepcopy(sources)
    sources, I, Q, directions = update_source_list(visibilities, meta, sources)
    names = getfield.(sources, 1)
    decisions = pick_sources_for_peeling_and_subtraction(spw, meta, sources, I, Q, directions, istest)
    to_peel, to_sub_bright, to_sub_faint, to_fit_with_shapelets = decisions
    if all(flags)
        empty!(to_peel)
        empty!(to_sub_bright)
        empty!(to_sub_faint)
        empty!(to_fit_with_shapelets)
    end

    if istest
        println("to_peel")
        println("-------")
        for source in sources[to_peel]
            @show source
        end
        println("")
        println("to_sub_bright")
        println("-------------")
        for source in sources[to_sub_bright]
            @show source
        end
        println("")
        println("to_sub_faint")
        println("-------------")
        for source in sources[to_sub_faint]
            @show source
        end
        println("")
        println("to_fit_with_shapelets")
        println("-------------")
        for source in sources[to_fit_with_shapelets]
            @show source
        end
        println("")
    end

    if dopeeling
        subsrc!(visibilities, meta, ConstantBeam(), sources[to_sub_bright])
        calibrations = peel!(visibilities, meta, ConstantBeam(), sources[to_peel],
                             peeliter=5, maxiter=100, tolerance=1e-3, quiet=!istest)

        # We need some resilience against bright fireballs getting in the way of peeling. So we will
        # check to see if the source was actually removed and put it back into the dataset if it was
        # not removed.
        if spw in (12, 14, 16, 18)
            keep = fill(true, length(to_peel))
            for index = 1:length(to_peel)
                master_index = to_peel[index]
                source = sources[master_index]
                model = genvis(meta, source)
                corrupt!(model, meta, calibrations[index])
                removed_I = getflux(model, meta, source)
                istest && @show source.name, removed_I, I[master_index]
                if abs(removed_I) < 0.9*abs(I[master_index])
                    putsrc!(visibilities, model)
                    keep[index] = false
                end
            end
            # Note: add the source to the list of "faint" sources so that it doesn't get re-added to
            # the image again in the putsrc! line below.
            to_sub_faint = [to_sub_faint; to_peel[!keep]]
            to_peel = to_peel[keep]
            calibrations = calibrations[keep]
        end

        putsrc!(visibilities, meta, ConstantBeam(), sources[to_sub_bright])
    else
        calibrations = GainCalibration[]
    end
    if dosubtraction
        fit_sources_with_shapelets!(meta, visibilities, @view(sources[to_fit_with_shapelets]))
        to_sub = [to_sub_bright; to_sub_faint; to_fit_with_shapelets]
        sources[to_sub] = original_sources[to_sub]
        update_source_list_in_place(visibilities, meta, @view(sources[to_sub]),
                                    @view(I[to_sub]), @view(Q[to_sub]), @view(directions[to_sub]))
        istest && @show sources[to_sub]
        subsrc!(visibilities, meta, ConstantBeam(), sources[to_sub])
    end
    data = PeelingData(time, sources, I, Q, directions, calibrations,
                       to_peel, to_sub_bright, to_sub_faint, to_fit_with_shapelets)

    # uncomment for testing purposes
    #visibilities = genvis(meta, sources[to_peel][1])
    #corrupt!(visibilities, meta, calibrations[1])

    xx = getfield.(visibilities.data[:, 1], 1)
    yy = getfield.(visibilities.data[:, 1], 4)
    xx, yy, data
end

macro pick_for_peeling(name, east_elevation_cutoff, west_elevation_cutoff,
                       flux_cutoff_high, flux_cutoff_low)
    output = quote
        if source.name == $name
            if is_rising(frame, source)
                θ = deg2rad($east_elevation_cutoff)
            else
                θ = deg2rad($west_elevation_cutoff)
            end
            is_above_elevation_cutoff = TTCal.isabovehorizon(frame, source, θ)
            if I[idx] ≥ $flux_cutoff_high && is_above_elevation_cutoff
                push!(to_peel, idx)
            elseif I[idx] ≥ $flux_cutoff_low
                push!(to_sub_bright, idx)
            end
        end
    end
    esc(output)
end

macro pick_for_subtraction(name, east_elevation_cutoff, west_elevation_cutoff,
                           flux_cutoff_high, flux_cutoff_low)
    output = quote
        if source.name == $name
            if is_rising(frame, source)
                θ = deg2rad($east_elevation_cutoff)
            else
                θ = deg2rad($west_elevation_cutoff)
            end
            is_above_elevation_cutoff = TTCal.isabovehorizon(frame, source, θ)
            if I[idx] ≥ $flux_cutoff_high && is_above_elevation_cutoff
                push!(to_sub_bright, idx)
            elseif I[idx] ≥ $flux_cutoff_low
                push!(to_sub_faint, idx)
            end
        end
    end
    esc(output)
end

macro pick_for_shapelets(name, elevation_cutoff)
    output = quote
        if source.name == $name
            if TTCal.isabovehorizon(frame, source, deg2rad($elevation_cutoff))
                push!(to_fit_with_shapelets, idx)
            end
        end
    end
    esc(output)
end

function pick_sources_for_peeling_and_subtraction(spw, meta, sources, I, Q, directions, istest=false)
    # We have three categories for how sources are removed:
    #  1) peel them (for very bright sources)
    #  2) subtract them after peeling (for faint sources)
    #  3) subtract them before peeling (for sources in the middle)
    # The third category is important because reasonably bright sources can interfere with the
    # peeling process if the flux of the two sources is comparable. For example, Cas A near the
    # horizon can create problems for trying to peel Vir A.
    to_peel = Int[]
    to_sub_faint  = Int[]
    to_sub_bright = Int[]
    to_fit_with_shapelets = Int[]
    frame = TTCal.reference_frame(meta)
    for idx = 1:length(sources)
        source = sources[idx]
        TTCal.isabovehorizon(frame, source) || continue
        if spw == 4
            #   Removal Technique    |   Name   | elev-e | elev-w | flux-hi | flux-lo |
            # -------------------------------------------------------------------------
            @pick_for_peeling          "Cyg A"     10        5       2000        30
            @pick_for_peeling          "Cas A"     10       10       1900        30
            @pick_for_peeling          "Vir A"     30       30       2500        30
            @pick_for_peeling          "Tau A"     30       30       2500        30
            @pick_for_subtraction      "Her A"     30       30        500        30
            @pick_for_subtraction      "Hya A"     60       60        500        30
            @pick_for_subtraction      "Per B"     60       60        500        30
            @pick_for_subtraction      "3C 353"    60       60        500        30
            @pick_for_shapelets        "Sun"        5
        elseif spw == 6
            #   Removal Technique    |   Name   | elev-e | elev-w | flux-hi | flux-lo |
            # -------------------------------------------------------------------------
            @pick_for_peeling          "Cyg A"     10       10       2000        30
            @pick_for_peeling          "Cas A"     10       10       2000        30
            @pick_for_peeling          "Vir A"     30       30       2000        30
            @pick_for_peeling          "Tau A"     30       30       2000        30
            @pick_for_subtraction      "Her A"     30       30        500        30
            @pick_for_subtraction      "Hya A"     60       60        500        30
            @pick_for_subtraction      "Per B"     60       60        500        30
            @pick_for_subtraction      "3C 353"    60       60        500        30
            @pick_for_shapelets        "Sun"        5
        elseif spw == 8
            #   Removal Technique    |   Name   | elev-e | elev-w | flux-hi | flux-lo |
            # -------------------------------------------------------------------------
            @pick_for_peeling          "Cyg A"     10       10       1000        30
            @pick_for_peeling          "Cas A"      8        8       1000        30
            @pick_for_peeling          "Vir A"     30       30       1000        30
            @pick_for_peeling          "Tau A"     30       30       1000        30
            @pick_for_subtraction      "Her A"     30       30        500        30
            @pick_for_subtraction      "Hya A"     60       60        500        30
            @pick_for_subtraction      "Per B"     60       60        500        30
            @pick_for_subtraction      "3C 353"    60       60        500        30
            @pick_for_shapelets        "Sun"        5
        elseif spw == 10
            #   Removal Technique    |   Name   | elev-e | elev-w | flux-hi | flux-lo |
            # -------------------------------------------------------------------------
            @pick_for_peeling          "Cyg A"     10       10       1000        30
            @pick_for_peeling          "Cas A"     10       10       1000        30
            @pick_for_peeling          "Vir A"     30       30       1000        30
            @pick_for_peeling          "Tau A"     30       30       1000        30
            @pick_for_subtraction      "Her A"     30       30        500        30
            @pick_for_subtraction      "Hya A"     60       60        500        30
            @pick_for_subtraction      "Per B"     60       60        500        30
            @pick_for_subtraction      "3C 353"    60       60        500        30
            @pick_for_shapelets        "Sun"        5
        elseif spw == 12
            #   Removal Technique    |   Name   | elev-e | elev-w | flux-hi | flux-lo |
            # -------------------------------------------------------------------------
            @pick_for_peeling          "Cyg A"     10       10       1000        30
            @pick_for_peeling          "Cas A"     10       10       1000        30
            @pick_for_peeling          "Vir A"     30       30       1000        30
            @pick_for_peeling          "Tau A"     30       30       1000        30
            @pick_for_subtraction      "Her A"     30       30        500        30
            @pick_for_subtraction      "Hya A"     60       60        500        30
            @pick_for_subtraction      "Per B"     60       60        500        30
            @pick_for_subtraction      "3C 353"    60       60        500        30
            @pick_for_peeling          "Sun"       15       15          0         0
        elseif spw == 14
            #   Removal Technique    |   Name   | elev-e | elev-w | flux-hi | flux-lo |
            # -------------------------------------------------------------------------
            @pick_for_peeling          "Cyg A"     10       10       1000        30
            @pick_for_peeling          "Cas A"     10       10       1000        30
            @pick_for_peeling          "Vir A"     30       30       1000        30
            @pick_for_peeling          "Tau A"     30       30       1000        30
            @pick_for_subtraction      "Her A"     30       30        500        30
            @pick_for_subtraction      "Hya A"     60       60        500        30
            @pick_for_subtraction      "Per B"     60       60        500        30
            @pick_for_subtraction      "3C 353"    60       60        500        30
            @pick_for_peeling          "Sun"       15       15          0         0
        elseif spw == 16
            #   Removal Technique    |   Name   | elev-e | elev-w | flux-hi | flux-lo |
            # -------------------------------------------------------------------------
            @pick_for_peeling          "Cyg A"     10       10       1000        30
            @pick_for_peeling          "Cas A"     10       10       1000        30
            @pick_for_peeling          "Vir A"     30       30       1000        30
            @pick_for_peeling          "Tau A"     30       30       1000        30
            @pick_for_subtraction      "Her A"     30       30        500        30
            @pick_for_subtraction      "Hya A"     60       60        500        30
            @pick_for_subtraction      "Per B"     60       60        500        30
            @pick_for_subtraction      "3C 353"    60       60        500        30
            @pick_for_peeling          "Sun"       15       15          0         0
        elseif spw == 18
            #   Removal Technique    |   Name   | elev-e | elev-w | flux-hi | flux-lo |
            # -------------------------------------------------------------------------
            @pick_for_peeling          "Cyg A"     10       10       1000        30
            @pick_for_peeling          "Cas A"     10       10       1000        30
            @pick_for_peeling          "Vir A"     30       30       1000        30
            @pick_for_peeling          "Tau A"     30       30       1000        30
            @pick_for_subtraction      "Her A"     30       30        500        30
            @pick_for_subtraction      "Hya A"     60       60        500        30
            @pick_for_subtraction      "Per B"     60       60        500        30
            @pick_for_subtraction      "3C 353"    60       60        500        30
            @pick_for_peeling          "Sun"       15       15          0         0
        end
    end

    # If a source we are trying to subtract has higher flux than a source we are trying to peel, we
    # should probably be peeling that source.
    move = zeros(Bool, length(to_sub_bright))
    for idx in to_sub_bright
        for jdx in to_peel
            if I[idx] > I[jdx]
                move[to_sub_bright .== idx] = true
            end
        end
    end
    to_peel = [to_peel; to_sub_bright[move]]
    to_sub_bright = to_sub_bright[!move]

    # If a source is much fainter than another source that is being peeled, it should be subtracted
    # instead.
    if length(to_peel) > 0
        max_I = maximum(I[to_peel])
        move = zeros(Bool, length(to_peel))
        for idx in to_peel
            if 10I[idx] < max_I
                move[to_peel .== idx] = true
            end
        end
        to_sub_bright = [to_sub_bright; to_peel[move]]
        to_peel = to_peel[!move]
    end

    fluxes = I[to_peel]
    perm = sortperm(fluxes, rev=true)
    istest && @show I
    istest && @show fluxes[perm]
    to_peel[perm], to_sub_bright, to_sub_faint, to_fit_with_shapelets
end

function fit_sources_with_shapelets!(meta, visibilities, sources)
    for idx = 1:length(sources)
        sources[idx] = fit_source_with_shapelets(meta, visibilities, sources[idx])
    end
end

function fit_source_with_shapelets(meta, visibilities, source)
    xx = getfield.(visibilities.data[:, 1], 1)
    yy = getfield.(visibilities.data[:, 1], 4)
    flags = visibilities.flags[:, 1]
    if source.name == "Sun"
        return fit_sun(meta, xx, yy, flags)
    else
        error("unknown shapelet source $(source.name)")
    end
end

function fit_sun(meta, xx, yy, flags)
    dir = Direction(dir"SUN")
    frame = TTCal.reference_frame(meta)
    fit_shapelets("Sun", meta, xx, yy, flags, dir, 6, deg2rad(27.25/60)/sqrt(8log(2)))
end

function fit_shapelets(name, meta, xx, yy, flags, dir, nmax, scale)
    coeff = zeros((nmax+1)^2)
    if !all(flags)
        rescaling = zeros((nmax+1)^2)
        matrix = zeros(Complex128, Nbase(meta), (nmax+1)^2)
        model = zeros(JonesMatrix, Nbase(meta), 1)
        for idx = 1:(nmax+1)^2
            coeff[:] = 0
            coeff[idx] = 1
            model[:] = zero(JonesMatrix)
            source = ShapeletSource("test", dir, PowerLaw(1, 0, 0, 0, 10e6, [0.0]), scale, coeff)
            TTCal.genvis_onesource!(model, meta, ConstantBeam(), source)
            for α = 1:Nbase(meta)
                # The model is unpolarized so the xx and yy components should be equal.
                matrix[α, idx] = model[α, 1].xx
            end
            rescaling[idx] = vecnorm(matrix[:, idx])
            matrix[:, idx] /= rescaling[idx]
        end

        vec = 0.5*(xx[!flags] + yy[!flags])
        matrix = matrix[!flags, :]
        vec = [vec; conj(vec)]
        matrix = [matrix; conj(matrix)]
        coeff = real(matrix\vec) ./ rescaling
    end
    ShapeletSource(name, dir, PowerLaw(1, 0, 0, 0, 10e6, [0.0]), scale, coeff)
end

# PROTOTYPING

macro fl(spw, ant1ant2)
    temp = split(string(ant1ant2), "&")
    ant1 = parse(Int, temp[1])
    ant2 = parse(Int, temp[2])
    esc(quote
        bad[$spw] = [bad[$spw]; $ant1 $ant2]
    end)
end

function prototype_peeling_flags(spw, flags)
    bad = Dict(spw => zeros(Int, 0, 2) for spw = 4:2:18)
    # eg. @fl 16 44&47
    bad_spw = bad[spw]
    for row = 1:size(bad_spw, 1)
        α = baseline_index(bad_spw[row, 1], bad_spw[row, 2])
        if flags !== nothing
            flags[α] = true
        end
    end
    bad[spw]
end

