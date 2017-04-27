function peel(spw, target="rfi-subtracted-calibrated-visiblities")
    dir = getdir(spw)
    times, data, flags = load(joinpath(dir, target*".jld"), "times", "data", "flags")
    peel(spw, target, times, data, flags)
end

immutable PeelingData
    time :: Float64
    sources :: Vector{Source}
    I :: Vector{Float64}
    Q :: Vector{Float64}
    directions :: Vector{Direction}
    to_peel :: Vector{Int}
    to_sub :: Vector{Int}
    calibrations :: Vector{GainCalibration}
end

function peel(spw, target, times, data, flags;
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
            remotecall(peel_worker_loop, worker, spw, input, output,
                       istest, dopeeling, dosubtraction)
            while true
                myidx = nextidx()
                myidx ≤ Ntime || break
                put!(input, (times[myidx], data[:, :, myidx], flags[:, myidx]))
                data[:, :, myidx], flags[:, myidx], peeling_data[myidx] = take!(output)
                increment_progress()
            end
            close(input)
            close(output)
        end
    end

    if !istest
        dir = getdir(spw)
        output_file = replace(replace(target, "calibrated", "peeled"), "rfi-subtracted-", "")
        output_file = replace(output_file, "rfi-subtracted-", "")
        output_file = replace(output_file, "twice-", "")
        output_file = joinpath(dir, output_file*".jld")
        isfile(output_file) && rm(output_file)
        save(output_file, "times", times, "data", data, "flags", flags,
             "peeling-data", peeling_data, compress=true)
    end

    peeling_data
end

function peel_worker_loop(spw, input, output, istest, dopeeling, dosubtraction)
    dir = getdir(spw)
    meta = getmeta(spw)
    meta.channels = meta.channels[55:55]
    sources = readsources(joinpath(sourcelists, "getdata-sources.json"))
    while true
        try
            time, data, flags = take!(input)
            peeling_data = peel_do_the_work(time, data, flags, spw, dir, meta, sources,
                                            istest, dopeeling, dosubtraction)
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
                          istest, dopeeling=true, dosubtraction=true)
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
                                      istest, dopeeling, dosubtraction)

    data[1, :] = xx
    data[2, :] = yy

    peeling_data
end

function rm_sources(time, flags, xx, yy, spw, meta, sources,
                    istest, dopeeling, dosubtraction)
    prototype_peeling_flags(spw, flags)
    visibilities = Visibilities(Nbase(meta), 1)
    for α = 1:Nbase(meta)
        visibilities.data[α, 1] = JonesMatrix(xx[α], 0, 0, yy[α])
        visibilities.flags[α, 1] = flags[α]
    end
    TTCal.flag_short_baselines!(visibilities, meta, 15.0)

    #sun = fit_sun(meta, xx, yy, flags)
    #sources = [sources; sun]

    sources, I, Q, directions = update_source_list(visibilities, meta, sources)
    names = getfield.(sources, 1)
    to_peel, to_sub = pick_sources_for_peeling_and_subtraction(spw, meta, sources, I, Q, directions)
    istest && @show sources[to_peel] sources[to_sub]

    if dopeeling
        calibrations = peel!(visibilities, meta, ConstantBeam(), sources[to_peel],
                             peeliter=5, maxiter=100, tolerance=1e-3, quiet=!istest)
    else
        calibrations = GainCalibration[]
    end
    if dosubtraction
        # re-fit all of the sources before subtracting
        #if "Sun" in names[to_sub]
            #idx = "Sun" .== names
            #sources[idx] = fit_sun(meta, visibilities)
        #end
        update_source_list_in_place(visibilities, meta, @view(sources[to_sub]),
                                    @view(I[to_sub]), @view(Q[to_sub]), @view(directions[to_sub]))
        istest && @show sources[to_sub]
        subsrc!(visibilities, meta, ConstantBeam(), sources[to_sub])
    end
    data = PeelingData(time, sources, I, Q, directions,
                       to_peel, to_sub, calibrations)

    # uncomment for testing purposes
    #visibilities = genvis(meta, sources[to_peel][1])
    #visibilities = genvis(meta, mysources[3])
    #corrupt!(visibilities, meta, calibrations[3])

    xx = getfield.(visibilities.data[:, 1], 1)
    yy = getfield.(visibilities.data[:, 1], 4)
    xx, yy, data
end

macro pick_for_peeling(name, elevation_cutoff)
    quote
        if source.name == $name
            I[idx] ≥ 30 || continue
            if TTCal.isabovehorizon(frame, source, deg2rad($elevation_cutoff))
                push!(to_peel, idx)
            else
                push!(to_sub, idx)
            end
        end
    end |> esc
end

macro pick_for_subtraction(name)
    quote
        if source.name == $name
            I[idx] ≥ 30 || continue
            push!(to_sub, idx)
        end
    end |> esc
end

macro special_case_the_sun(elevation_cutoff)
    quote
        if source.name == "Sun"
            if TTCal.isabovehorizon(frame, source, deg2rad($elevation_cutoff))
                push!(to_peel, idx)
            else
                push!(to_sub, idx)
            end
        end
    end |> esc
end

function pick_sources_for_peeling_and_subtraction(spw, meta, sources, I, Q, directions)
    to_peel = Int[]
    to_sub  = Int[]
    frame = TTCal.reference_frame(meta)
    for idx = 1:length(sources)
        source = sources[idx]
        TTCal.isabovehorizon(frame, source) || continue
        if spw == 4
            @pick_for_peeling "Cyg A" 15
            @pick_for_peeling "Cas A" 10
            @pick_for_peeling "Vir A" 60
            @pick_for_subtraction "Tau A"
            @pick_for_subtraction "Her A"
            @pick_for_subtraction "Hya A"
            @pick_for_subtraction "Per B"
            @pick_for_subtraction "3C 353"
            @special_case_the_sun 30
        elseif spw == 6
            @pick_for_peeling "Cyg A" 15
            @pick_for_peeling "Cas A" 10
            @pick_for_subtraction "Vir A"
            @pick_for_subtraction "Tau A"
            @pick_for_subtraction "Her A"
            @pick_for_subtraction "Hya A"
            @pick_for_subtraction "Per B"
            @pick_for_subtraction "3C 353"
            @special_case_the_sun 30
        elseif spw == 8
            @pick_for_peeling "Cyg A" 15
            @pick_for_peeling "Cas A" 10
            @pick_for_subtraction "Vir A"
            @pick_for_subtraction "Tau A"
            @pick_for_subtraction "Her A"
            @pick_for_subtraction "Hya A"
            @pick_for_subtraction "Per B"
            @pick_for_subtraction "3C 353"
            @special_case_the_sun 30
        elseif spw == 10
            @pick_for_peeling "Cyg A" 15
            @pick_for_peeling "Cas A" 10
            @pick_for_subtraction "Vir A"
            @pick_for_subtraction "Tau A"
            @pick_for_subtraction "Her A"
            @pick_for_subtraction "Hya A"
            @pick_for_subtraction "Per B"
            @pick_for_subtraction "3C 353"
            @special_case_the_sun 30
        elseif spw == 12
            @pick_for_peeling "Cyg A" 10
            @pick_for_peeling "Cas A" 5
            @pick_for_peeling "Vir A" 45
            @pick_for_subtraction "Tau A"
            @pick_for_subtraction "Her A"
            @pick_for_subtraction "Hya A"
            @pick_for_subtraction "Per B"
            @pick_for_subtraction "3C 353"
            @special_case_the_sun 15
        elseif spw == 14
            @pick_for_peeling "Cyg A" 10
            @pick_for_peeling "Cas A" 5
            @pick_for_peeling "Vir A" 45
            @pick_for_subtraction "Tau A"
            @pick_for_subtraction "Her A"
            @pick_for_subtraction "Hya A"
            @pick_for_subtraction "Per B"
            @pick_for_subtraction "3C 353"
            @special_case_the_sun 15
        elseif spw == 16
            @pick_for_peeling "Cyg A" 10
            @pick_for_peeling "Cas A" 5
            @pick_for_peeling "Vir A" 45
            @pick_for_subtraction "Tau A"
            @pick_for_subtraction "Her A"
            @pick_for_subtraction "Hya A"
            @pick_for_subtraction "Per B"
            @pick_for_subtraction "3C 353"
            @special_case_the_sun 15
        elseif spw == 18
            @pick_for_peeling "Cyg A" 10
            @pick_for_peeling "Cas A" 5 # note that Cas A never drops below 5 degrees elevation
            @pick_for_peeling "Vir A" 45
            @pick_for_subtraction "Tau A"
            @pick_for_subtraction "Her A"
            @pick_for_subtraction "Hya A"
            @pick_for_subtraction "Per B"
            @pick_for_subtraction "3C 353"
            @special_case_the_sun 15
        end
    end

    # TODO we'd probably like to be able to specify a range of sidereal times a
    # source should be peeled, rather than just a cut in elevation

    # If a source we are trying to subtract has higher flux than a source we are trying to peel, we
    # should probably be peeling that source.
    move = zeros(Bool, length(to_sub))
    for idx in to_sub
        for jdx in to_peel
            if I[idx] > I[jdx]
                move[to_sub .== idx] = true
            end
        end
    end
    to_peel = [to_peel; to_sub[move]]
    to_sub  = to_sub[!move]

    fluxes = I[to_peel]
    perm = sortperm(fluxes, rev=true)
    to_peel[perm], to_sub
end

function fit_sun(meta, visibilities)
    xx = getfield.(visibilities.data[:, 1], 1)
    yy = getfield.(visibilities.data[:, 1], 4)
    flags = visibilities.flags[:, 1]
    fit_sun(meta, xx, yy, flags)
end

function fit_sun(meta, xx, yy, flags)
    dir = Direction(dir"SUN")
    frame = TTCal.reference_frame(meta)
    output = Source[]
    if TTCal.isabovehorizon(frame, dir) && !all(flags)
        sun = fit_shapelets("Sun", meta, xx, yy, flags, dir, 5, deg2rad(27.25/60)/sqrt(8log(2)))
        push!(output, sun)
    end
    output
end

function fit_shapelets(name, meta, xx, yy, flags, dir, nmax, scale)
    coeff = zeros((nmax+1)^2)
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

