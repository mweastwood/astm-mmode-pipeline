function getsun(spw)
    dadas = listdadas(spw)
    caltimes, cal1, cal2 = readcals(spw)
    integration = 5082 # 1:00 pm local time
    pattern = [integration - 1000; integration - 500; integration; integration + 500]
    Ntime = 6628
    for idx = 1:4*length(pattern)
        jdx = ((idx - 1) % length(pattern)) + 1
        kdx = ((idx - 1) ÷ length(pattern)) + 1
        index = pattern[jdx] + (kdx-1)*Ntime
        index > length(dadas) && break
        dada = dadas[index]
        getsun(spw, dada, @sprintf("%02d", idx))
    end
end

function getsun(spw, input, output)
    Lumberjack.info("Constructing a shapelet model for the Sun with $input")
    ms, path = dada2ms(input)
    caltimes, cal1, cal2 = readcals(spw)
    local time, shapelets
    try
        flag!(ms)
        data = get_data(ms)
        meta = collect_metadata(ms, ConstantBeam())
        frame = TTCal.reference_frame(meta)

        time = ms["TIME", 1]
        idx = indmin(abs2(caltimes-time))
        applycal!(data, meta, cal1[idx])
        #applycal!(data, meta, cal2[idx]) # this calibration seems suspect

        oldflags = copy(data.flags)
        flag_short_baselines!(data, meta, 15.0)

        sources = readsources(joinpath(sourcelists, "cyg-cas.json"))
        sources = TTCal.abovehorizon(frame, sources)
        shavings = shave!(data, meta, sources)

        sun = Direction(dir"SUN")
        shapelets = fit_shapelets("Sun", meta, data, sun, 5, deg2rad(0.2))
        subsrc!(data, meta, [shapelets])

        data.flags = oldflags
        set_corrected_data!(ms, data)
        TTCal.set_flags!(ms, data)

    finally
        finalize(ms)
    end

    dir = joinpath(getdir(spw), "solar-models")
    isdir(dir) || mkdir(dir)
    model_name = joinpath(dir, "$output.jld")
    ms_name    = joinpath(dir, "$output.ms")

    Lumberjack.info("Saving the model of the sun to $model_name")
    save(model_name, "sun", shapelets, "time", time)
    Lumberjack.info("Saving the measurement set to $ms_name")
    cp(path, ms_name, remove_destination=true)
    Lumberjack.info("Creating an image of the measurement set at $ms_name")
    wsclean(ms_name)

    rm(path, recursive=true)

end

function fit_shapelets(name, meta, data, dir, nmax, scale)
    coeff = zeros((nmax+1)^2)
    rescaling = zeros((nmax+1)^2)
    matrix = zeros(Complex128, Nbase(meta)*Nfreq(meta), (nmax+1)^2)
    model = zeros(JonesMatrix, Nbase(meta), Nfreq(meta))
    for idx = 1:(nmax+1)^2
        coeff[:] = 0
        coeff[idx] = 1
        source = ShapeletSource("test", dir, PowerLaw(1, 0, 0, 0, 10e6, [0.0]), scale, coeff)
        #model = genvis(meta, source) # rate limiting step
        model[:] = zero(JonesMatrix)
        TTCal.genvis_onesource!(model, meta, ConstantBeam(), source)
        for β = 1:Nfreq(meta), α = 1:Nbase(meta)
            jdx = (β-1)*Nbase(meta) + α
            #matrix[jdx, idx] = 0.5*(model.data[α,β].xx + model.data[α,β].yy)
            matrix[jdx, idx] = 0.5*(model[α,β].xx + model[α,β].yy)
        end
        rescaling[idx] = vecnorm(matrix[:,idx])
        matrix[:,idx] = matrix[:,idx]/rescaling[idx]
    end

    vec = zeros(Complex128, Nbase(meta)*Nfreq(meta))
    for β = 1:Nfreq(meta), α = 1:Nbase(meta)
        jdx = (β-1)*Nbase(meta) + α
        if meta.baselines[α].antenna1 == meta.baselines[α].antenna2 || data.flags[α,β]
            matrix[jdx,:] = 0
            vec[jdx] = 0
        else
            vec[jdx] = 0.5*(data.data[α,β].xx + data.data[α,β].yy)
        end
    end

    matrix = [matrix; conj(matrix)]
    vec    = [vec; conj(vec)]

    #@time A = matrix'*matrix
    #@time b = matrix'*vec
    #@time λ = maximum(eigvals(A))
    #@time A = A + 0.001λ*I
    #@time coeff = real(A\b) ./ rescaling
    coeff = real(matrix\vec) ./ rescaling

    ShapeletSource(name, dir, PowerLaw(1, 0, 0, 0, 10e6, [0.0]), scale, coeff)
end

function readsuns(spw)
    dir = joinpath(getdir(spw), "solar-models")
    models = readdir(dir)
    filter!(models) do file
        endswith(file, ".jld")
    end
    times = Float64[]
    suns = ShapeletSource[]
    for model in models
        mysun, mytime = load(joinpath(dir, model), "sun", "time")
        push!(suns, mysun)
        push!(times, mytime)
    end
    idx = sortperm(times)
    times = times[idx]
    suns = suns[idx]
    times, suns
end

