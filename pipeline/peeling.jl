function peel(spw, times, data, flags; istest=false)
    Ntime = length(times)
    idx = 1
    nextidx() = (myidx = idx; idx += 1; myidx)

    p = Progress(Ntime)
    l = ReentrantLock()
    increment_progress() = (lock(l); next!(p); unlock(l))

    @sync for worker in workers()
        @async begin
            input  = RemoteChannel()
            output = RemoteChannel()
            remotecall(peel_worker_loop, worker, spw, input, output)
            while true
                myidx = nextidx()
                myidx ≤ Ntime || break
                put!(input, (times[myidx], data[:, :, myidx], flags[:, myidx]))
                data[:, :, myidx], flags[:, myidx] = take!(output)
                increment_progress()
            end
            close(input)
            close(output)
        end
    end

    if !istest
        dir = getdir(spw)
        output_file = joinpath(dir, "peeled-visibilities.jld")
        save(output_file, "times", times, "data", data, "flags", flags, compress=true)
    end
end

function peel_worker_loop(spw, input, output)
    dir = getdir(spw)
    meta = getmeta(spw)
    meta.channels = meta.channels[55:55]
    xx_rfi, yy_rfi = load(joinpath(dir, "rfi-components.jld"), "xx", "yy")
    sources = readsources(joinpath(sourcelists, "getdata-sources.json"))
    while true
        try
            time, data, flags = take!(input)
            peel_do_the_work(time, data, flags, spw, dir, meta, xx_rfi, yy_rfi, sources)
            put!(output, (data, flags))
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

function peel_do_the_work(time, data, flags, spw, dir, meta, xx_rfi, yy_rfi, sources)
    xx = data[1, :]
    yy = data[2, :]

    meta.time = Epoch(epoch"UTC", time*seconds)
    meta.phase_center = Direction(dir"AZEL", 0degrees, 90degrees)

    # flag the auto correlations
    for ant = 1:Nant(meta)
        α = baseline_index(ant, ant)
        flags[α] = true
    end

    xx, yy = rm_rfi(flags, xx, yy, xx_rfi, yy_rfi)
    xx, yy = rm_sources(flags, xx, yy, spw, meta, sources)

    data[1, :] = xx
    data[2, :] = yy
end

function rm_rfi(flags, xx, yy, xx_rfi, yy_rfi)
    if !all(flags)
        xx_flagged = xx[!flags]
        yy_flagged = yy[!flags]
        xx_rfi_flagged = xx_rfi[!flags, :]
        yy_rfi_flagged = yy_rfi[!flags, :]
        xx_flux = xx_rfi_flagged \ xx_flagged
        yy_flux = yy_rfi_flagged \ yy_flagged
        xx -= xx_rfi * xx_flux
        yy -= yy_rfi * yy_flux
    end
    xx, yy
end

function rm_sources(flags, xx, yy, spw, meta, sources)
    visibilities = Visibilities(Nbase(meta), 1)
    for α = 1:Nbase(meta)
        visibilities.data[α, 1] = JonesMatrix(xx[α], 0, 0, yy[α])
        visibilities.flags[α, 1] = flags[α]
    end
    TTCal.flag_short_baselines!(visibilities, meta, 15.0)

    sun = fit_sun(meta, xx, yy, flags)
    sources = [sources; sun]

    sources, I, Q, directions = update_source_list(visibilities, meta, sources)
    peeling_sources, subtraction_sources = pick_sources_for_peeling_and_subtraction(spw, meta, sources, I, Q, directions)
    calibrations = peel!(visibilities, meta, ConstantBeam(), peeling_sources,
                         peeliter=5, maxiter=100, tolerance=1e-3, quiet=true)
    subsrc!(visibilities, meta, ConstantBeam(), subtraction_sources)

    xx = getfield.(visibilities.data[:, 1], 1)
    yy = getfield.(visibilities.data[:, 1], 4)
    xx, yy
end

function pick_sources_for_peeling_and_subtraction(spw, meta, sources, I, Q, directions)
    peeling_sources = Source[]
    subtraction_sources = Source[]
    fluxes = Float64[] # keep track of peeling source fluxes to sort in order of decreasing flux
    frame = TTCal.reference_frame(meta)
    for idx = 1:length(sources)
        source = sources[idx]
        TTCal.isabovehorizon(frame, source) || continue
        if source.name == "Cyg A" || source.name == "Cas A"
            I[idx] ≥ 30 || continue
            if TTCal.isabovehorizon(frame, source, deg2rad(10))
                push!(peeling_sources, source)
                push!(fluxes, I[idx])
            else
                push!(subtraction_sources, source)
            end
        elseif source.name == "Sun"
            if TTCal.isabovehorizon(frame, source, deg2rad(30))
                push!(peeling_sources, source)
                push!(fluxes, I[idx])
            else
                push!(subtraction_sources, source)
            end
        end
    end
    perm = sortperm(fluxes, rev=true)
    peeling_sources[perm], subtraction_sources
end

function fit_sun(meta, xx, yy, flags)
    dir = Direction(dir"SUN")
    frame = TTCal.reference_frame(meta)
    output = Source[]
    if TTCal.isabovehorizon(frame, dir) && !all(flags)
        sun = fit_shapelets("Sun", meta, xx, yy, flags, dir, 5, deg2rad(0.2))
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

