module Driver

using LibHealpix
using CasaCore.Measures
using TTCal
using BPJSpec
using ProgressMeter
using JLD
using Distributions

function base_simulation()
    meta = load("/lustre/mweastwood/mmode-analysis/workspace/spw18/metadata.jld", "metadata")
    meta.channels = meta.channels[55:55]
    times = load("/lustre/mweastwood/mmode-analysis/workspace/spw04/visibilities.jld", "times")
    beam = SineBeam()

    visibilities = zeros(Complex128, Nbase(meta), 6628)
    model = PointSource("Point", Direction(dir"J2000", "0h", "0d"),
                        PowerLaw(1, 0, 0, 0, 10e6, [0.0]))

    p = Progress(6628, "Progress: ")
    for idx = 1:6628
        meta.time = Epoch(epoch"UTC", times[idx]*seconds)
        frame = TTCal.reference_frame(meta)
        if !TTCal.isabovehorizon(frame, model)
            next!(p)
            continue
        end
        meta.phase_center = measure(frame, Direction(dir"AZEL", 0degrees, 90degrees), dir"J2000")
        model_visibilities = genvis(meta, beam, model).data
        for α = 1:Nbase(meta)
            visibilities[α, idx] = 0.5*(model_visibilities[α, 1].xx + model_visibilities[α, 1].yy)
        end
        next!(p)
    end

    gridded = GriddedVisibilities("base-visibilities", Nbase(meta), 6628, meta.channels, 0.0)
    gridded[1] = visibilities
    mmodes = MModes("base-mmodes", gridded, 1000)
    transfermatrix = TransferMatrix("/lustre/mweastwood/mmode-analysis/workspace/spw18/transfermatrix")

    alm = _getalm(transfermatrix, mmodes, 0.01)
    map = alm2map(alm, 512)
    writehealpix("base-map.fits", map, replace=true)
end

function scintillation_simulation()
    meta = load("/lustre/mweastwood/mmode-analysis/workspace/spw18/metadata.jld", "metadata")
    meta.channels = meta.channels[55:55]
    times = load("/lustre/mweastwood/mmode-analysis/workspace/spw04/visibilities.jld", "times")
    beam = SineBeam()

    visibilities = zeros(Complex128, Nbase(meta), 6628)
    model = PointSource("Point", Direction(dir"J2000", "0h", "0d"),
                        PowerLaw(1, 0, 0, 0, 10e6, [0.0]))
    c = Cauchy(1.0, 0.3)
    fluxes = rand(c, 6628)
    fluxes = clamp(fluxes, 0.01, 10)
    elevations = zeros(6628)

    p = Progress(6628, "Progress: ")
    for idx = 1:6628
        meta.time = Epoch(epoch"UTC", times[idx]*seconds)
        frame = TTCal.reference_frame(meta)
        if !TTCal.isabovehorizon(frame, model)
            next!(p)
            continue
        end
        meta.phase_center = measure(frame, Direction(dir"AZEL", 0degrees, 90degrees), dir"J2000")
        model.spectrum = PowerLaw(fluxes[idx], 0, 0, 0, 10e6, [0.0])
        elevations[idx] = latitude(measure(frame, model.direction, dir"AZEL"))
        model_visibilities = genvis(meta, beam, model).data
        for α = 1:Nbase(meta)
            visibilities[α, idx] = 0.5*(model_visibilities[α, 1].xx + model_visibilities[α, 1].yy)
        end
        next!(p)
    end

    @show any(isnan(visibilities))

    gridded = GriddedVisibilities("scintillation-visibilities", Nbase(meta), 6628, meta.channels, 0.0)
    gridded[1] = visibilities
    mmodes = MModes("scintillation-mmodes", gridded, 1000)
    transfermatrix = TransferMatrix("/lustre/mweastwood/mmode-analysis/workspace/spw18/transfermatrix")

    alm = _getalm(transfermatrix, mmodes, 0.01)
    map = alm2map(alm, 512)
    writehealpix("scintillation-map.fits", map, replace=true)

    save("scintillation-flux.jld", "flux", fluxes, "time", times, "elevation", elevations)
end

function refraction_simulation()
    meta = load("/lustre/mweastwood/mmode-analysis/workspace/spw18/metadata.jld", "metadata")
    meta.channels = meta.channels[55:55]
    times = load("/lustre/mweastwood/mmode-analysis/workspace/spw04/visibilities.jld", "times")
    beam = SineBeam()

    visibilities = zeros(Complex128, Nbase(meta), 6628)
    model = PointSource("Point", Direction(dir"J2000", "0h", "0d"),
                        PowerLaw(1, 0, 0, 0, 10e6, [0.0]))
    δy = deg2rad(30/60)*randn(6628)
    δz = deg2rad(30/60)*randn(6628)
    fy = rfft(δy)
    fz = rfft(δz)
    fy[end-3000:end] = 0
    fz[end-3000:end] = 0
    δy = irfft(fy, 6628)
    δz = irfft(fz, 6628)
    save("refraction-position.jld", "dy", δy, "dz", δz)

    p = Progress(6628, "Progress: ")
    for idx = 1:6628
        meta.time = Epoch(epoch"UTC", times[idx]*seconds)
        frame = TTCal.reference_frame(meta)
        meta.phase_center = measure(frame, Direction(dir"AZEL", 0degrees, 90degrees), dir"J2000")
        x = sqrt(1 - δy[idx]^2 - δz[idx]^2)
        model.direction = Direction(dir"J2000", x, δy[idx], δz[idx])
        if !TTCal.isabovehorizon(frame, model)
            next!(p)
            continue
        end
        model_visibilities = genvis(meta, beam, model).data
        for α = 1:Nbase(meta)
            visibilities[α, idx] = 0.5*(model_visibilities[α, 1].xx + model_visibilities[α, 1].yy)
        end
        next!(p)
    end

    gridded = GriddedVisibilities("refraction-visibilities", Nbase(meta), 6628, meta.channels, 0.0)
    gridded[1] = visibilities
    mmodes = MModes("refraction-mmodes", gridded, 1000)
    transfermatrix = TransferMatrix("/lustre/mweastwood/mmode-analysis/workspace/spw18/transfermatrix")

    alm = _getalm(transfermatrix, mmodes, 0.01)
    map = alm2map(alm, 512)
    writehealpix("refraction-map.fits", map, replace=true)
end

function _getalm(transfermatrix::TransferMatrix, mmodes, tolerance)
    lmax = transfermatrix.lmax
    mmax = transfermatrix.mmax
    alm = Alm(Complex128, lmax, mmax)
    m = 0
    nextm() = (m′ = m; m += 1; m′)
    prg = Progress(mmax+1, "Progress: ")
    lck = ReentrantLock()
    increment_progress() = (lock(lck); next!(prg); unlock(lck))
    @sync for worker in workers()
        @async begin
            input_channel  = RemoteChannel()
            output_channel = RemoteChannel()
            try
                remotecall(getalm_remote_processing_loop, worker, input_channel, output_channel, transfermatrix, mmodes, tolerance)
                while true
                    m′ = nextm()
                    m′ ≤ mmax || break
                    put!(input_channel, m′)
                    block = take!(output_channel)
                    for l = m′:lmax
                        alm[l,m′] = block[l-m′+1]
                    end
                    increment_progress()
                end
            finally
                close(input_channel)
                close(output_channel)
            end
        end
    end
    alm
end

function getalm_remote_processing_loop(input, output, transfermatrix, mmodes, tolerance)
    BLAS.set_num_threads(16) # compensate for a bug in `addprocs`
    while true
        m = take!(input)
        A = transfermatrix[m,1]
        b = mmodes[m,1]
        BPJSpec.account_for_flags!(A, b)
        x = tikhonov(A, b, tolerance)
        put!(output, x)
    end
end

end

