immutable SourceSummary
    category :: Vector{Int}
    t :: Vector{Float64}
    I :: Vector{Float64}
    Q :: Vector{Float64}
    U :: Vector{Float64}
    V :: Vector{Float64}
    az :: Vector{Float64}
    el :: Vector{Float64}
    ra :: Vector{Float64}
    dec :: Vector{Float64}
    model :: Vector{Source}
    cal :: Vector{GainCalibration}
end

function SourceSummary()
    SourceSummary(Int[], Float64[], Float64[], Float64[], Float64[], Float64[],
                  Float64[], Float64[], Float64[], Float64[], Source[], GainCalibration[])
end

function update_summary!(summary, category, frame, time, spectrum, direction, source, calibration)
    push!(summary.category, category)
    push!(summary.t, time)
    jones = mean(spectrum)
    stokes = StokesVector(jones)
    push!(summary.I, stokes.I)
    push!(summary.Q, stokes.Q)
    push!(summary.U, stokes.U)
    push!(summary.V, stokes.V)
    set!(frame, Epoch(epoch"UTC", time*seconds))
    azel = measure(frame, direction, dir"AZEL")
    j2000 = measure(frame, direction, dir"J2000")
    push!(summary.az, longitude(azel))
    push!(summary.el, latitude(azel))
    push!(summary.ra, longitude(j2000))
    push!(summary.dec, latitude(j2000))
    push!(summary.model, TTCal.unwrap(source))
    push!(summary.cal, calibration)
end

function update_summary!(summary, category, frame, time, spectrum, source, direction)
    update_summary!(summary, category, frame, time, spectrum, direction, source, GainCalibration(256, 109))
end

function makecurves(spw)
    dir = getdir(spw)
    tmp = joinpath(dir, "tmp")
    files = readdir(tmp)
    jlds = filter(files) do file
        endswith(file, ".jld") && !startswith(file, "test")
    end
    sort!(jlds)
    meta = getmeta(spw)
    frame = TTCal.reference_frame(meta)
    times = load(joinpath(dir, "visibilities.jld"), "times")

    #_makecurves(spw, 1, jlds[1:6628], times[1:6628], frame)
    #_makecurves(spw, 2, jlds[6629:13256], times[6629:13256], frame)
    _makecurves(spw, 3, jlds[13257:19884], times[13257:19884], frame)
    _makecurves(spw, 4, jlds[19885:end], times[19885:end], frame)
end

function _makecurves(spw, idx, jlds, times, frame)
    dir = getdir(spw)
    tmp = joinpath(dir, "tmp")
    p = Progress(length(jlds), "Progress: ")
    summaries = Dict{String, SourceSummary}()
    for (time, jld) in zip(times, jlds)
        path = joinpath(tmp, jld)
        local A, B, C
        try
            A, B, C = load(path, "A", "B", "C")
        catch e
            @show path
            throw(e)
        end
        for (calibration, source, spectrum, direction) in zip(A...)
            name = TTCal.unwrap(source).name
            haskey(summaries, name) || (summaries[name] = SourceSummary())
            update_summary!(summaries[name], 1, frame, time, spectrum, direction, source, calibration)
        end
        for (calibration, source, spectrum, direction) in zip(B...)
            name = TTCal.unwrap(source).name
            haskey(summaries, name) || (summaries[name] = SourceSummary())
            update_summary!(summaries[name], 2, frame, time, spectrum, direction, source, calibration)
        end
        for (source, spectrum, direction) in zip(C...)
            name = TTCal.unwrap(source).name
            haskey(summaries, name) || (summaries[name] = SourceSummary())
            update_summary!(summaries[name], 3, frame, time, spectrum, source, direction)
        end
        next!(p)
    end

    save(joinpath(dir, "collated-source-information-day$idx.jld"), "summary", summaries)

    nothing
end

