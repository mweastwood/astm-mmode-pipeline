module Driver

using LibHealpix
using CasaCore.Measures
using TTCal
using ProgressMeter
using JLD

include("../Pipeline.jl")

macro setup()
    output = quote
        spw = 4
        dataset = "rainy"
        dir = Pipeline.Common.getdir(spw)
        workspace = joinpath(dirname(@__FILE__), "..", "..", "workspace")

        meta = Pipeline.Common.getmeta(spw, dataset)
        meta.channels = meta.channels[55:55]
        meta.phase_center = Direction(dir"AZEL", 0degrees, 90degrees)

        times = load(joinpath(dir, "raw-rainy-visibilities.jld"), "times")
        beam = SineBeam()
        flags = zeros(Bool, Nbase(meta), length(times))

        direction = Direction(dir"J2000", "23h23m24s", "+58d48m54s")
        source = PointSource("Cas A", direction, PowerLaw(1, 0, 0, 0, 10e6, [0.0]))

        _expected_light_curve = load(joinpath(workspace, "expected-light-curves-rainy.jld"), "I")
        expected_light_curve = _expected_light_curve[spw][2, :]

        _light_curve, _flags = load(joinpath(workspace, "light-curves-rainy.jld"), "I", "flags")
        light_curve = _light_curve[spw][2, :]
        light_curve_flags = _flags[spw][2, :]

        _dra, _ddec, _flags = load(joinpath(workspace, "refraction-curves-rainy.jld"),
                                   "dra", "ddec", "flags")
        δra = _dra[spw][2, :]
        δdec = _ddec[spw][2, :]
        refraction_flags = _flags[spw][2, :]
    end
    esc(output)
end

macro image()
    output = quote
        visibilities, flags = Pipeline.MModes._fold(4, visibilities, flags, "simulation", "")
        mmodes, mmode_flags = Pipeline.MModes.getmmodes_internal(visibilities, flags)
        alm = Pipeline.MModes._getalm(spw, mmodes, mmode_flags, tolerance=0.01)
        map = alm2map(alm, 2048)
        img = Pipeline.Cleaning.postage_stamp(map, direction)
    end
    esc(output)
end

function base_simulation_visibilities(meta, source, times, light_curve)
    N = length(times)
    visibilities = zeros(Complex128, 2, Nbase(meta), N)
    p = Progress(N)
    for idx = 1:N
        meta.time = Epoch(epoch"UTC", times[idx]*seconds)
        frame = TTCal.reference_frame(meta)
        if !TTCal.isabovehorizon(frame, source)
            next!(p)
            continue
        end
        model_visibilities = genvis(meta, ConstantBeam(), source).data
        for α = 1:Nbase(meta)
            visibilities[1, α, idx] = light_curve[idx]*model_visibilities[α, 1].xx
            visibilities[2, α, idx] = light_curve[idx]*model_visibilities[α, 1].yy
        end
        next!(p)
    end
    visibilities
end

function base_simulation()
    @setup
    #visibilities = base_simulation_visibilities(meta, source, times, expected_light_curve)
    #@image
    #writehealpix("base-map.fits", map, replace=true)
    map = readhealpix("base-map.fits")
    meta = Pipeline.Common.getmeta(spw, dataset)
    frame = TTCal.reference_frame(meta)
    img = Pipeline.Cleaning.postage_stamp(map, measure(frame, direction, dir"ITRF"))
    save("base-image.jld", "img", img)
end

function scintillation_simulation_visibilities(meta, source, times, light_curve,
                                               expected_light_curve, light_curve_flags)
    N = length(times)
    frame = TTCal.reference_frame(meta)
    visibilities = zeros(Complex128, 2, Nbase(meta), N)
    p = Progress(N)
    for idx = 1:N
        meta.time = Epoch(epoch"UTC", times[idx]*seconds)
        frame = TTCal.reference_frame(meta)
        if !TTCal.isabovehorizon(frame, source)
            next!(p)
            continue
        end
        model_visibilities = genvis(meta, ConstantBeam(), source).data
        flux = light_curve_flags[idx] ? expected_light_curve[idx] : light_curve[idx]
        for α = 1:Nbase(meta)
            visibilities[1, α, idx] = flux*model_visibilities[α, 1].xx
            visibilities[2, α, idx] = flux*model_visibilities[α, 1].yy
        end
        next!(p)
    end
    visibilities
end

function scintillation_simulation()
    @setup
    #visibilities = scintillation_simulation_visibilities(meta, source, times, light_curve,
    #                                                     expected_light_curve, light_curve_flags)
    #@image
    #writehealpix("scintillation-map.fits", map, replace=true)
    map = readhealpix("scintillation-map.fits")
    meta = Pipeline.Common.getmeta(spw, dataset)
    frame = TTCal.reference_frame(meta)
    img = Pipeline.Cleaning.postage_stamp(map, measure(frame, direction, dir"ITRF"))
    save("scintillation-flux.jld", "img", img)
end

function refraction_simulation_visibilities(meta, source, times, light_curve,
                                            δra, δdec, refraction_flags)
    N = length(times)
    frame = TTCal.reference_frame(meta)
    visibilities = zeros(Complex128, 2, Nbase(meta), N)
    p = Progress(N)
    for idx = 1:N
        meta.time = Epoch(epoch"UTC", times[idx]*seconds)
        frame = TTCal.reference_frame(meta)
        if !TTCal.isabovehorizon(frame, source)
            next!(p)
            continue
        end
        mysource = deepcopy(source)
        if !refraction_flags[idx]
            ra = longitude(mysource.direction) + deg2rad(δra[idx]*60)
            dec = latitude(mysource.direction) + deg2rad(δdec[idx]*60)
            mysource.direction = Direction(dir"J2000", ra*radians, dec*radians)
        end
        model_visibilities = genvis(meta, ConstantBeam(), mysource).data
        for α = 1:Nbase(meta)
            visibilities[1, α, idx] = light_curve[idx]*model_visibilities[α, 1].xx
            visibilities[2, α, idx] = light_curve[idx]*model_visibilities[α, 1].yy
        end
        next!(p)
    end
    visibilities
end

function refraction_simulation()
    @setup
    #visibilities = refraction_simulation_visibilities(meta, source, times, light_curve,
    #                                                  δra, δdec, refraction_flags)
    #@image
    #writehealpix("refraction-map.fits", map, replace=true)
    map = readhealpix("refraction-map.fits")
    meta = Pipeline.Common.getmeta(spw, dataset)
    frame = TTCal.reference_frame(meta)
    img = Pipeline.Cleaning.postage_stamp(map, measure(frame, direction, dir"ITRF"))
    save("refraction-position.jld", "img", img)
end

end

