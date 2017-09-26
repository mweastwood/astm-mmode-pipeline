module Driver

using LibHealpix
using CasaCore.Measures
using TTCal
using ProgressMeter
using JLD

include("../Pipeline.jl")

function go(; I=1.0, Q=0.1)
    spw = 18
    dataset = "rainy"
    dir = Pipeline.Common.getdir(spw)
    workspace = joinpath(dirname(@__FILE__), "..", "..", "workspace")

    meta = Pipeline.Common.getmeta(spw, dataset)
    meta.channels = meta.channels[55:55]
    meta.phase_center = Direction(dir"AZEL", 0degrees, 90degrees)

    times = load(joinpath(dir, "raw-rainy-visibilities.jld"), "times")
    flags = zeros(Bool, Nbase(meta), length(times))

    coeff_I, coeff_Q = load(joinpath(dir, "beam.jld"), "I-coeff", "Q-coeff")
    direction = Direction(dir"J2000", "23h23m24s", "+58d48m54s")
    visibilities = get_visibilities(meta, times, direction, I, Q, coeff_I, coeff_Q)

    visibilities, flags = Pipeline.MModes._fold(spw, visibilities, flags, "simulation", "")
    mmodes, mmode_flags = Pipeline.MModes.getmmodes_internal(visibilities, flags)
    alm = Pipeline.MModes._getalm(spw, mmodes, mmode_flags, tolerance=0.01)
    map = alm2map(alm, 2048)

    frame = TTCal.reference_frame(Pipeline.Common.getmeta(spw, dataset))
    img = Pipeline.Cleaning.postage_stamp(map, measure(frame, direction, dir"ITRF"))

    save("I=$I-Q=$Q.jld", "img", img)
end

function get_visibilities(meta, times, direction, I, Q, coeff_I, coeff_Q)
    N = length(times)
    visibilities = zeros(Complex128, 2, Nbase(meta), N)
    p = Progress(N)
    for idx = 1:N
        meta.time = Epoch(epoch"UTC", times[idx]*seconds)
        frame = TTCal.reference_frame(meta)
        azel = measure(frame, direction, dir"AZEL")
        az = longitude(azel)
        el =  latitude(azel)
        if el < 0
            next!(p)
            continue
        end

        ρ = cos(el)
        θ = az
        stokes_I_beam = (coeff_I[1]*TTCal.zernike(0, 0, ρ, θ)
                        + coeff_I[2]*TTCal.zernike(2, 0, ρ, θ)
                        + coeff_I[3]*TTCal.zernike(4, 0, ρ, θ)
                        + coeff_I[4]*TTCal.zernike(4, 4, ρ, θ)
                        + coeff_I[5]*TTCal.zernike(6, 0, ρ, θ)
                        + coeff_I[6]*TTCal.zernike(6, 4, ρ, θ)
                        + coeff_I[7]*TTCal.zernike(8, 0, ρ, θ)
                        + coeff_I[8]*TTCal.zernike(8, 4, ρ, θ)
                        + coeff_I[9]*TTCal.zernike(8, 8, ρ, θ))
        stokes_Q_beam = (coeff_Q[1]*TTCal.zernike(2, 2, ρ, θ)
                        + coeff_Q[2]*TTCal.zernike(4, 2, ρ, θ)
                        + coeff_Q[3]*TTCal.zernike(6, 2, ρ, θ)
                        + coeff_Q[4]*TTCal.zernike(6, 6, ρ, θ)
                        + coeff_Q[5]*TTCal.zernike(8, 2, ρ, θ)
                        + coeff_Q[6]*TTCal.zernike(8, 6, ρ, θ))

        source = PointSource("Cas A", direction, PowerLaw(stokes_I_beam*I + stokes_Q_beam*Q,
                                                          stokes_I_beam*Q + stokes_Q_beam*I,
                                                          0, 0, 10e6, [0.0]))
        model_visibilities = genvis(meta, ConstantBeam(), source).data
        for α = 1:Nbase(meta)
            visibilities[1, α, idx] = model_visibilities[α, 1].xx
            visibilities[2, α, idx] = model_visibilities[α, 1].yy
        end
        next!(p)
    end
    visibilities
end

end

