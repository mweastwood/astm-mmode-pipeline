function light_curves(dataset)
    names = Dict{Int, Vector{String}}()
    t = Dict{Int, Vector{Float64}}()
    I = Dict{Int, Matrix{Float64}}()
    flags = Dict{Int, Matrix{Bool}}()
    for spw = 4:2:18
        @show spw
        @time names[spw], t[spw], I[spw], flags[spw] = light_curves(spw, dataset)
    end

    save(joinpath(dirname(@__FILE__), "..", "..", "workspace", "light-curves-$dataset.jld"),
         "names", names, "t", t, "I", I, "flags", flags)
end

function light_curves(spw, dataset)
    dir = getdir(spw)
    peeling_data = load(joinpath(dir, "peeled-$dataset-visibilities.jld"), "peeling-data")

    names = ["Cyg A", "Cas A"]

    N  = length(peeling_data)
    t  = zeros(N)
    I  = zeros(length(names), N)
    flags = zeros(Bool, length(names), N)

    meta = getmeta(spw, dataset)
    frame = TTCal.reference_frame(meta)

    for idx = 1:N
        data = peeling_data[idx]
        t[idx] = data.time

        for jdx = 1:length(names)
            _names = [source.name for source in data.sources]
            s = first(find(_names .== names[jdx]))

            if data.I[s] == data.Q[s] == 0
                flags[jdx, idx] = true
                continue
            end

            I[jdx, idx] = data.I[s]
        end
    end

    names, t, I, flags
end

function expected_light_curves(dataset)
    names = Dict{Int, Vector{String}}()
    t = Dict{Int, Vector{Float64}}()
    I = Dict{Int, Matrix{Float64}}()
    flags = Dict{Int, Matrix{Bool}}()
    for spw = 4:2:18
        @show spw
        @time names[spw], t[spw], I[spw], flags[spw] = expected_light_curves(spw, dataset)
    end

    save(joinpath(dirname(@__FILE__), "..", "..", "workspace", "expected-light-curves-$dataset.jld"),
         "names", names, "t", t, "I", I, "flags", flags)
end

function expected_light_curves(spw, dataset)
    dir = getdir(spw)
    peeling_data = load(joinpath(dir, "peeled-$dataset-visibilities.jld"), "peeling-data")

    workspace = joinpath(dirname(@__FILE__), "..", "..", "workspace")
    spectra, sources = load(joinpath(workspace, "spectra.jld"), "spectra", "sources")

    beam = load(joinpath(dir, "beam.jld"), "I-coeff")

    meta = getmeta(spw, dataset)
    frame = TTCal.reference_frame(meta)

    expected_light_curves_kernel(spw, frame, peeling_data, spectra, sources, beam)
end


function expected_light_curves_kernel(spw, frame, peeling_data, spectra, sources, beam)
    names = ["Cyg A", "Cas A"]

    N  = length(peeling_data)
    t  = zeros(N)
    I  = zeros(length(sources), N)
    flags = zeros(Bool, length(sources), N)

    for idx = 1:N
        data = peeling_data[idx]

        t[idx] = data.time
        set!(frame, Epoch(epoch"UTC", data.time*seconds))

        for jdx = 1:length(names)
            name = names[jdx]
            azel = measure(frame, sources[name], dir"AZEL")
            az = longitude(azel)
            el =  latitude(azel)

            if el < 0
                flags[jdx, idx] = true
                continue
            end

            l = sin(az) * cos(el)
            m = cos(az) * cos(el)
            ρ = hypot(l, m)
            θ = atan2(l, m)

            stokes_I_beam = (beam[1]*TTCal.zernike(0, 0, ρ, θ)
                           + beam[2]*TTCal.zernike(2, 0, ρ, θ)
                           + beam[3]*TTCal.zernike(4, 0, ρ, θ)
                           + beam[4]*TTCal.zernike(4, 4, ρ, θ)
                           + beam[5]*TTCal.zernike(6, 0, ρ, θ)
                           + beam[6]*TTCal.zernike(6, 4, ρ, θ)
                           + beam[7]*TTCal.zernike(8, 0, ρ, θ)
                           + beam[8]*TTCal.zernike(8, 4, ρ, θ)
                           + beam[9]*TTCal.zernike(8, 8, ρ, θ))

            kdx = first(find([4:2:18;] .== spw))
            I[jdx, idx] = stokes_I_beam*spectra[name][kdx]
        end
    end

    names, t, I, flags
end

