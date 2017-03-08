module PeelingTests

using JLD
using CasaCore.Tables
using CasaCore.Measures
using MLPFlagger
using TTCal
using BPJSpec
using LibHealpix
using NLopt
using ProgressMeter

# 6628 integrations per sidereal day (assuming 13 s integrations).
const Ntime = 6628

# Gregg's favorite channel is #48 in subband 16.
const subband = 16
const channel = 48

const dir = "/lustre/data/2016-03-19_100hour_run"
const files = readdir(joinpath(dir, "00")) |> sort
filter!(files) do file
    startswith(file, "2016-03-19-01:44:01")
end
deleteat!(files, (Ntime+1):length(files))

baseline_index(ant1, ant2) = div((ant1-1)*(512-(ant1-2)), 2) + (ant2-ant1+1)

function dada2ms(dada::AbstractString, ms)
    run(`dada2ms-mwe $dada $ms`)
    run(`swap_polarizations_from_delay_bug $ms`)
end

function dada2ms(idx)
    output_dir = "peeling-tests"
    cal = load("workspace/calibrations/day1.jld", "cal")
    file = files[1:663:end][idx]
    dada = joinpath(dir, @sprintf("%02d", subband), file)
    output = joinpath(output_dir, replace(file, "dada", "ms"))
    dada2ms(dada, output)
    ms = Table(ascii(output))
    data = TTCal.get_data(ms)
    meta = collect_metadata(ms, ConstantBeam())
    applycal!(data, meta, cal)
    TTCal.set_data!(ms, data)
    TTCal.set_flags!(ms, data)
    ms
end

function getmeta(ms, beam = ConstantBeam())
    meta = collect_metadata(ms, ConstantBeam())
    meta.channels = meta.channels[channel:channel]
    meta
end

function getdata(ms)
    data = TTCal.get_data(ms)
    data.data  = data.data[:,channel:channel]
    data.flags = data.flags[:,channel:channel]
    data
end

function putdata!(ms, data, flags=false)
    N = (256*257)÷2
    expanded_data = Visibilities(zeros(JonesMatrix, N, 109), fill(true, N, 109))
    expanded_data.data[:,channel] = data.data
    expanded_data.flags[:,channel] = data.flags
    TTCal.set_corrected_data!(ms, expanded_data, true)
    flags && TTCal.set_flags!(ms, expanded_data)
end

function suppress_rfi()
    ms = dada2ms(7)
    meta = getmeta(ms)
    data = getdata(ms)
    flag_short_baselines!(data, meta, 15.0)

    sources_to_peel = readsources("sources-to-peel.json")
    meta.beam = Memo178Beam()
    peelings = peel!(GainCalibration, data, meta, sources_to_peel,
                     peeliter=5, maxiter=100, tolerance=1e-3)

    #diffuse = diffuse_model_visibilities(ms)
    #data.data -= diffuse.data

    rfi = [Position(pos"WGS84", 1226.7091391887516meters, -118.3147833410907degrees, 37.145402389570144degrees),
           Position(pos"WGS84", 1214.248326037079meters, -118.3852914162684degrees, 37.3078474772316degrees),
           Position(pos"WGS84", 1232.7690506698564meters, -118.37296747772183degrees, 37.24935118263112degrees),
           Position(pos"WGS84", 1608.21583019197meters, -118.23417138204732degrees, 37.06249388547446degrees)]

    coherencies = Visibilities[]
    for position in rfi
        source = TTCal.RFISource("RFI", position, TTCal.RFISpectrum(meta.channels, [StokesVector(1, 0, 0, 0)]))
        meta.beam = ConstantBeam()
        model = genvis(meta, source)
        push!(coherencies, model)
    end

    vector = zeros(Complex128, Nbase(meta))
    matrix = zeros(Complex128, Nbase(meta), length(rfi))
    for α = 1:Nbase(meta)
        data.flags[α,1] && continue
        vector[α] = 0.5*(data.data[α,1].xx + data.data[α,1].yy)
        for idx = 1:length(rfi)
            matrix[α,idx] = 0.5*(coherencies[idx].data[α,1].xx + coherencies[idx].data[α,1].yy)
        end
    end
    matrix = [matrix; conj(matrix)]
    vector = [vector; conj(vector)]
    flux = real(matrix \ vector)
    @show flux

    sources = TTCal.RFISource[]
    for idx = 1:length(rfi)
        position = rfi[idx]
        spectrum = TTCal.RFISpectrum(meta.channels, [StokesVector(flux[idx], 0, 0, 0)])
        source = TTCal.RFISource("RFI", position, spectrum)
        push!(sources, source)
    end

    model = genvis(meta, sources)
    data.data -= model.data
    #data.data += diffuse.data

    putdata!(ms, data)
end

function svd_of_residuals()
    #visibilities = GriddedVisibilities("workspace/visibilities-combined")
    #modelvisibilities = GriddedVisibilities("workspace/model-visibilities")
    #grid = visibilities[1] - modelvisibilities[1]
    #save("workspace/grid.jld", "grid", grid)
    #@time grid = load("workspace/grid.jld", "grid")
    #@time U, S, V = svd(grid) # this takes about 30 min (with OMP_NUM_THREADS=16)
    #save("workspace/svd.jld", "U", U, "S", S, "V", V)
    @time U, S = load("workspace/svd.jld", "U", "S")

    #idx = 5
    #@show S[idx]
    #ms = dada2ms(7)
    #meta = getmeta(ms)
    #data = getdata(ms)
    #for α = 1:Nbase(meta)
    #    correlation = U[α,idx]
    #    data.data[α,1] = JonesMatrix(correlation, 0, 0, correlation)
    #end
    #putdata!(ms, data)

    ms = dada2ms(8)
    meta = getmeta(ms)
    data = getdata(ms)
    flags = data.flags[:,1]

    #=
    sources_to_peel = readsources("sources-to-peel.json")
    meta.beam = Memo178Beam()
    peelings = peel!(GainCalibration, data, meta, sources_to_peel,
                     peeliter=5, maxiter=100, tolerance=1e-3)

    @time diffuse = diffuse_model_visibilities(ms)
    data.data -= diffuse.data

    sun = fit_shapelets(meta, data, Direction(dir"SUN"), 5, deg2rad(0.2))
    model = genvis(meta, sun)
    data.data -= model.data
    =#

    vector = zeros(Complex128, Nbase(meta))
    for α = 1:Nbase(meta)
        vector[α] = 0.5*(data.data[α,1].xx + data.data[α,1].yy)
    end

    #save("peeling-tests/vector.jld", "vector", vector)
    #vector = load("peeling-tests/vector.jld", "vector")
    vector[flags] = 0

    for idx = 1:5
        singularvector = slice(U, :, idx)
        #singularvector[flags] = 0
        overlap = dot(singularvector, vector)
        vector -= overlap * singularvector
        @show overlap
    end

    for α = 1:Nbase(meta)
        correlation = vector[α]
        data.data[α,1] = JonesMatrix(correlation, 0, 0, correlation)
    end
    putdata!(ms, data)

    nothing
end

function svd_suppression_test()
    @time U, S, V = load("workspace/svd.jld", "U", "S", "V")
    @time S[6:end] = 0
    @time to_subtract = U*diagm(S)*V'

    @time visibilities = GriddedVisibilities("workspace/visibilities-combined-svd-rfi-suppression")
    p = Progress(length(to_subtract), "Progress: ")
    for t = 1:6628, α = 1:32896
        visibilities.data[1][α,t] -= to_subtract[α,t]
        next!(p)
    end
end

function sum_over_everything()
    ms = dada2ms(7)
    #ms = Table("peeling-tests/2016-03-19-01:44:01_0000458216718336.000000.ms")
    @show ms
    meta = getmeta(ms)
    data = getdata(ms)
    flag_short_baselines!(data, meta, 15.0)
    frame = TTCal.reference_frame(meta)

    #counts = zeros(Int, 256)
    #for ant1 = 1:256, ant2 = ant1:256
    #    α = baseline_index(ant1, ant2)
    #    if data.flags[α,1]
    #        counts[ant1] += 1
    #        ant1 == ant2 && continue
    #        counts[ant2] += 1
    #    end
    #end
    #@show counts
    #@show find(counts .== 256)
    #return

    visibilities = GriddedVisibilities("workspace/visibilities-combined")
    #modelvisibilities = GriddedVisibilities("workspace/model-visibilities")
    @time visibilities_grid = visibilities[1]
    #@time modelvisibilities_grid = modelvisibilities[1]
    @time summed = sum(visibilities_grid, 2)
    #@time summed = sum(modelvisibilities_grid, 2)

    #save("peeling-tests/summed.jld", "summed", summed)
    #summed = load("peeling-tests/summed.jld", "summed")

    for ant1 = 1:256, ant2 = ant1:256
        α = baseline_index(ant1, ant2)
        correlation = summed[α]
        data.data[α,1] = JonesMatrix(correlation, 0, 0, correlation)
        #data.flags[α,1] = false
    end

    pos = TTCal.position(meta)
    vec = [pos.x, pos.y, pos.z]
    up = vec / norm(vec)
    north  = [0, 0, 1] - dot([0, 0, 1], up)*up
    north /= norm(north)
    east = cross(north, up)

    az = Float64[]
    el = 1.0
    dist = Float64[]
    for δaz in linspace(-165, -164, 50), δdist in logspace(log10(1e3), log10(30e3), 100)
    #for δaz in linspace(-49, -52, 50), δdist in logspace(log10(1e3), log10(30e3), 100)
    #for δaz in linspace(-82, -84, 50), δdist in logspace(log10(1e3), log10(30e3), 100)
    #for δaz in linspace(167, 169, 50), δdist in logspace(log10(1e3), log10(30e3), 100)
        push!(az, δaz)
        push!(dist, δdist)
    end

    N = length(az)
    matrix = zeros(Complex128, Nbase(meta), N)
    @time for idx = 1:N
        #mydir = Direction(dir"AZEL", az[idx]*degrees, el[idx]*degrees)
        #source = PointSource("test", mydir, PowerLaw(1, 0, 0, 0, 10e6, [0.0]))

        myvec = vec + (cosd(az[idx])*cosd(el)*dist[idx]*north
                        + sind(az[idx])*cosd(el)*dist[idx]*east
                        + sind(el)*dist[idx]*up)
        mypos = Position(pos"ITRF", myvec[1], myvec[2], myvec[3])
        source = TTCal.RFISource("test", mypos, TTCal.RFISpectrum(meta.channels, [StokesVector(1, 0, 0, 0)]))

        model = genvis(meta, source)
        for α = 1:Nbase(meta)
            matrix[α,idx] = 0.5*(model.data[α,1].xx + model.data[α,1].yy)
        end
        idx += 1
    end

    vec = zeros(Complex128, Nbase(meta))
    @time for α = 1:Nbase(meta)
        if abs(meta.baselines[α].antenna1 - meta.baselines[α].antenna2) ≤ 1 || data.flags[α,1]
            matrix[α,:] = 0
        else
            vec[α] = 0.5*(data.data[α,1].xx + data.data[α,1].yy)
        end
    end

#    @time matrix = [matrix; conj(matrix)]
#    @time vec    = [vec; conj(vec)]
#
    #@time A = matrix'*matrix
    #@time b = matrix'*vec
    #@time λ = maximum(eigvals(A))
    #@time A = A + 0.0001λ*I
    #@time coeff = real(A\b)
    ##save("peeling-tests/coeff.jld", "coeff", coeff, "az", az, "el", el)
    #save("peeling-tests/coeff.jld", "coeff", coeff, "az", az, "dist", dist)

    #v = matrix*coeff
    #for α = 1:Nbase(meta)
    #    correlation = v[α]
    #    data.data[α,1] -= JonesMatrix(correlation, 0, 0, correlation)
    #end

    #@show measure(frame, Direction(dir"J2000", "18h29m21s", "-46d31m29s"), dir"AZEL")
    #@show measure(frame, Direction(dir"J2000", "21h15m50s", "-48d18m36s"), dir"AZEL")

#    sources = TTCal.Source[]
#    fluxes = Float64[]
#    for dir in [Direction(dir"AZEL", "-50d36m09s", "+3d20m20s"),
#                Direction(dir"AZEL", "-82d08m38s", "+2d09m28s"),
#                Direction(dir"AZEL", "-164d13m09s", "+3d52m37s"),
#                Direction(dir"AZEL", "+167d52m00s", "+3d09m01s")]
#        flux = getspec(data, meta, dir) |> mean |> TTCal.stokes
#        #push!(sources, PointSource("rfi", dir, PowerLaw(flux, 1e6, [0.0])))
#        push!(fluxes, flux.I)
#        source = fit_shapelets(meta, data, dir, 5, deg2rad(10/60))
#        push!(sources, source)
#    end
#
#    idx = sortperm(fluxes, rev=true)
#    sources = sources[idx]
#
    #peelings = peel!(GainCalibration, data, meta, sources,
    #                 peeliter=3, maxiter=100, tolerance=1e-3)

    #idx = 2
    #model = genvis(meta, sources[idx])
    #corrupt!(model, meta, peelings[idx])

    #rfi = [PointSource("1", Direction(dir"AZEL", "-82d08m38s", "+2d09m28s"),
    #                   PowerLaw(1, 0, 0, 0, 10e6, [0.0]))]
    #       #PointSource("2", Direction(dir"AZEL", "-50d36m09s", "+3d20m20s"),
    #                   #PowerLaw(1, 0, 0, 0, 10e6, [0.0]))]
    #peelings = peel!(GainCalibration, data, meta, rfi,
    #                 peeliter=3, maxiter=100, tolerance=1e-3)

    #rfi = PointSource("rfi", Direction(dir"AZEL", 0degrees, 90degrees), PowerLaw(1, 0, 0, 0, 10e6, [0.0]))
    #sources = fill(rfi, 10)
    #peelings = peel!(GainCalibration, data, meta, sources,
    #                 peeliter=3, maxiter=100, tolerance=1e-3)

    #rfi = fit_shapelets(meta, data, Direction(dir"AZEL", "-82d08m38s", "+2d09m28s"), 5, deg2rad(10/60))
    #model = genvis(meta, rfi)
    #data.data -= model.data

    #putdata!(ms, model)
    putdata!(ms, data)
    nothing
end

function google_maps()
    ms = Table("peeling-tests/2016-03-19-01:44:01_0000458216718336.000000.ms")
    meta = getmeta(ms)
    data = getdata(ms)
    frame = TTCal.reference_frame(meta)

    pos = TTCal.position(meta)
    vec = [pos.x, pos.y, pos.z]
    up = vec / norm(vec)
    north  = [0, 0, 1] - dot([0, 0, 1], up)*up
    north /= norm(north)
    east = cross(north, up)

    coeff, az, dist = load("peeling-tests/coeff.jld", "coeff", "az", "dist")
    el = 1.0
    N = length(coeff)
    output = zeros(0,3)
    for idx = 1:N
        if coeff[idx] > 30000
            myvec = vec + (cosd(az[idx])*cosd(el)*dist[idx]*north
                          + sind(az[idx])*cosd(el)*dist[idx]*east
                          + sind(el)*dist[idx]*up)
            mypos = Position(pos"ITRF", myvec[1], myvec[2], myvec[3])
            wgs84 = measure(frame, mypos, pos"WGS84")
            long = longitude(wgs84) |> rad2deg
            lat = latitude(wgs84) |> rad2deg
            output = [output; coeff[idx] long lat]
        end
    end
    writecsv("peeling-tests/coeff.csv", output)
end

function fit_for_rfi_location()
    ms = Table("peeling-tests/2016-03-19-01:44:01_0000458216718336.000000.ms")
    meta = getmeta(ms)
    data = getdata(ms)
    flag_short_baselines!(data, meta, 15.0)
    frame = TTCal.reference_frame(meta)
    summed = load("peeling-tests/summed.jld", "summed")
    for ant1 = 1:256, ant2 = ant1:256
        α = baseline_index(ant1, ant2)
        correlation = summed[α]
        data.data[α,1] = JonesMatrix(correlation, 0, 0, correlation)
    end

    pos = TTCal.position(meta)
    vec = [pos.x, pos.y, pos.z]
    up = vec / norm(vec)
    north  = [0, 0, 1] - dot([0, 0, 1], up)*up
    north /= norm(north)
    east = cross(north, up)

    function flux(x, g)
        az = x[1]
        el = x[2]
        dist = x[3]
        myvec = vec + (cosd(az)*cosd(el)*dist*north
                        + sind(az)*cosd(el)*dist*east
                        + sind(el)*dist*up)
        mypos = Position(pos"ITRF", myvec[1], myvec[2], myvec[3])
        source = TTCal.RFISource("test", mypos, TTCal.RFISpectrum(meta.channels, [StokesVector(1, 0, 0, 0)]))
        model = genvis(meta, source)

        vector = zeros(Complex128, Nbase(meta))
        matrix = zeros(Complex128, Nbase(meta), 1)
        for α = 1:Nbase(meta)
            data.flags[α,1] && continue
            vector[α] = 0.5*(data.data[α,1].xx + data.data[α,1].yy)
            matrix[α] = 0.5*(model.data[α,1].xx + model.data[α,1].yy)
        end

        matrix = [matrix; conj(matrix)]
        vector = [vector; conj(vector)]
        A = matrix'*matrix
        b = matrix'*vector
        out = real(A\b)[1]

        #@show x,out
        out
    end

    output = zeros(0, 3)
    #for x0 in ([-164.644, 1.0, 11257.8],
    #           [-50.617, 1.0, 11655.7],
    #           [-82.8811, 1.0, 8558.19],
    #           [167.754, 1.0, 20912.5])
    for iter = 1:4
        x0 = [0.0, 1.0, 10e3]

        opt = Opt(:GN_ESCH, 3)
        max_objective!(opt, flux)
        maxtime!(opt, 60)
        lower_bounds!(opt, [-180, -1.0,  1e3])
        upper_bounds!(opt, [+180, +5.0, 30e3])
        f, x, ret = optimize(opt, x0)
        println("---")
        @show f x ret

        opt = Opt(:LN_NELDERMEAD, 3)
        max_objective!(opt, flux)
        xtol_rel!(opt, 1e-5)
        lower_bounds!(opt, [-180, -1.0,  1e3])
        upper_bounds!(opt, [+180, +5.0, 30e3])
        f, x, ret = optimize(opt, x)

        az = x[1]
        el = x[2]
        dist = x[3]
        myvec = vec + (cosd(az)*cosd(el)*dist*north
                        + sind(az)*cosd(el)*dist*east
                        + sind(el)*dist*up)
        mypos = Position(pos"ITRF", myvec[1], myvec[2], myvec[3])
        source = TTCal.RFISource("test", mypos, TTCal.RFISpectrum(meta.channels, [StokesVector(f, 0, 0, 0)]))
        model = genvis(meta, source)

        data.data -= model.data

        println("---")
        @show f
        @show x
        @show ret
        wgs84 = measure(frame, mypos, pos"WGS84")
        @show wgs84
        @show latitude(wgs84) |> rad2deg
        @show longitude(wgs84) |> rad2deg
        @show radius(wgs84)
        println("---")

        output = [output; rad2deg(latitude(wgs84)) rad2deg(longitude(wgs84)) radius(wgs84)]
    end
    writecsv("peeling-tests/best-fit.csv", output)
    putdata!(ms, data)
end

function blot_out_point_sources()
    alm = load("workspace/alm.jld", "alm")

    nside = 2048
    @time map = alm2map(alm, nside)

    ms = Table("workspace/cal.ms")
    meta = collect_metadata(ms, ConstantBeam())
    frame = TTCal.reference_frame(meta)

    j2000_blots = [Direction(dir"J2000", "19h59m28.35663s", "+40d44m02.0970s"), # Cyg A
                   Direction(dir"J2000", "23h23m24s", "+58d48m54s"), # Cas A
                   Direction(dir"J2000", "12h30m49.42338s", "+12d23m28.0439s"), # Vir A
                   Direction(dir"J2000", "05h34m31.94s", "+22d00m52.2s"), # Tau A
                   Direction(dir"J2000", "16h51m11.4s", "+04d59m20s"), # Her A
                   Direction(dir"J2000", "09h18m05.651s", "-12d05m43.99s"), # Hya A
                   Direction(dir"J2000", "04h37m04.3753s", "+29d40m13.819s"), # Per B
                   Direction(dir"SUN")]
    itrf_blots = [measure(frame, dir, dir"ITRF") for dir in j2000_blots]

    N = length(itrf_blots)
    blot_pixels    = [Int[] for idx = 1:N]
    annulus_pixels = [Int[] for idx = 1:N]

    @time for pix = 1:length(map)
        vec = LibHealpix.pix2vec_ring(nside, pix)
        for idx = 1:N
            blot = itrf_blots[idx]
            product = vec[1]*blot.x + vec[2]*blot.y + vec[3]*blot.z
            degrees = acosd(product)
            if degrees < 2.0
                push!(blot_pixels[idx], pix)
            end
            if 3.0 < degrees < 4.0
                push!(annulus_pixels[idx], pix)
            end
        end
    end

    @time for idx = 1:N
        value = median([map[pix] for pix in annulus_pixels[idx]])
        @show value
        for pix in blot_pixels[idx]
            map[pix] = value
        end
    end

    @time newalm = map2alm(map, 1000, 1000, iterations=10)

    writehealpix("workspace/blotted.fits", map, replace=true)
    save("workspace/blotted-alm.jld", "alm", newalm)
end

function diffuse_model_visibilities(ms)
    meta = getmeta(ms)
    data = getdata(ms)
    visibilities = GriddedVisibilities("workspace/model-visibilities")
    data_grid = visibilities[1]
    Nbase, Ntime = size(data_grid)
    time = mod(BPJSpec.sidereal_time(meta) - visibilities.origin, 1)

    Δt = 1/Ntime
    times = 0.0:Δt:(1.0-Δt)
    idx1 = searchsortedlast(times, time)
    idx2 = idx1 == Ntime? 1 : idx1+1
    weight1 = 1 - (time - times[idx1])/Δt
    weight2 = 1 - weight1 # note this handles the case where the second grid point has wrapped around
    for α = 1:Nbase
        correlation = weight1*data_grid[α,idx1] + weight2*data_grid[α,idx2]
        data.data[α,1] = JonesMatrix(correlation, 0, 0, correlation)
        data.flags[α,1] = false
    end
    data
end

function image_the_model()
    ms = dada2ms(7)
    data = diffuse_model_visibilities(ms)
    putdata!(ms, data)
end

function experiment_with_point_source_strategy(idx)
    @show idx
    ms = dada2ms(idx)
    @show ms
    meta = getmeta(ms)
    data = getdata(ms)
    #original_data = deepcopy(data)
    #noflags = copy(data.flags)
    #flag_short_baselines!(data, meta, 15.0)
    #shortflags = copy(data.flags)
    frame = TTCal.reference_frame(meta)

    diffuse = diffuse_model_visibilities(ms)
    data.data -= diffuse.data

    for ant1 = 1:256, ant2 = ant1:256
        suspicious = (44, 45, 199, 200, 210, 211)
        if ant1 in suspicious || ant2 in suspicious
            α = baseline_index(ant1, ant2)
            data.flags[α,1] = true
        end
    end

    xx = zeros(Complex128, Nbase(meta))
    yy = zeros(Complex128, Nbase(meta))
    for α = 1:Nbase(meta)
        data.flags[α,1] && continue
        xx[α] = data.data[α,1].xx
        yy[α] = data.data[α,1].yy
    end
    flags = xx .== 0

    N = 10
    U = load("workspace/svd.jld", "U")
    matrix = zeros(Complex128, Nbase(meta), N)
    for idx = 1:N
        singularvector = slice(U, :, idx)
        singularvector[flags] = 0
        matrix[:,idx] = singularvector
    end

    overlap = matrix \ xx
    xx = xx - (matrix*overlap)
    overlap = matrix \ yy
    yy = yy - (matrix*overlap)

    for α = 1:Nbase(meta)
        data.data[α,1] = JonesMatrix(xx[α], 0, 0, yy[α])
    end

    sources = readsources("sources.json")
    flag_short_baselines!(data, meta, 15.0)

    for ant = 1:255
        α = baseline_index(ant, ant+1)
        data.flags[α,1] = true
    end

    cas = sources[1]
    casdir = fitvis(data, meta, Direction(dir"J2000", "23h24m37s", "+58d25m28s"))
    casflux = getspec(data, meta, casdir) |> mean |> TTCal.stokes
    cas.direction = casdir
    cas.spectrum = TTCal.PowerLaw(casflux.I, 0, 0, 0, 1e6, [0.0])
    @show casdir casflux

    vir = sources[4]
    virdir = fitvis(data, meta, Direction(dir"J2000", "12h30m31s", "+12d27m47s"))
    virflux = getspec(data, meta, virdir) |> mean |> TTCal.stokes
    vir.direction = virdir
    vir.spectrum = TTCal.PowerLaw(virflux.I, 0, 0, 0, 1e6, [0.0])
    @show virdir virflux

    #subsrc!(data, meta, [cas, vir])

    peelings = peel!(GainCalibration, data, meta, [vir, cas],
                     peeliter=3, maxiter=30, tolerance=1e-3)

    #model = genvis(meta, cas)
    #corrupt!(model, meta, peelings[1])
    #putdata!(ms, model)
    putdata!(ms, data, true)
    return

    data.data += diffuse.data

    #=
    sources_to_peel = readsources("sources-to-peel.json")
    sources_to_subtract = readsources("sources-to-subtract.json")
    direction_to_sun = Direction(dir"SUN")

    filter!(sources_to_peel) do source
        dir  = source.direction
        azel = measure(frame, dir, dir"AZEL")
        el   = latitude(azel) |> rad2deg
        if el < 0
            return false
        elseif el < 20
            push!(sources_to_subtract, source)
            return false
        end
        true
    end
    filter!(sources_to_subtract) do source
        TTCal.isabovehorizon(frame, source)
    end

    if TTCal.isabovehorizon(frame, direction_to_sun)
        use_sun = true
    else
        use_sun = false
    end

    sources = [sources_to_peel; sources_to_subtract]

    println("Peel:")
    for source in sources_to_peel
        @show source.name
    end
    println("Subtract:")
    for source in sources_to_subtract
        @show source.name
    end

    # build the sky model
    data.flags = noflags
    meta.beam = ZernikeBeam()

    diffuse = diffuse_model_visibilities(ms)
    data.data -= diffuse.data

    peelings = peel!(GainCalibration, data, meta, sources,
                     peeliter=3, maxiter=30, tolerance=1e-3)

    #model = genvis(meta, sources)
    #model.data += diffuse.data

    #cal = gaincal(data, meta, model, maxiter=30, tolerance=1e-3)
    #applycal!(data, meta, cal)
    #data.data -= model.data
    =#

    #=
    meta.beam = ZernikeBeam()
    if length(sources_to_peel) ≥ 2
        data.flags = shortflags
        peelings = peel!(GainCalibration, data, meta, sources_to_peel,
                         peeliter=5, maxiter=100, tolerance=1e-3)
    elseif length(sources_to_peel) ≥ 1
        data.flags = shortflags
        peelings = peel!(GainCalibration, data, meta, sources_to_peel,
                         peeliter=1, maxiter=100, tolerance=1e-3)
    end

    meta.beam = ConstantBeam()
    if use_sun
        data.flags = shortflags
        sun = fit_shapelets(meta, data, Direction(dir"SUN"), 5, deg2rad(0.2))
        sun_visibilities = genvis(meta, sun)
        data.data -= sun_visibilities.data
    end

    meta.beam = ConstantBeam()
    for source in sources_to_subtract
        data.flags = noflags
        dir = fitvis(data, meta, source.direction)
        data.flags = shortflags
        flux = getspec(data, meta, dir) |> mean |> TTCal.stokes
        source.direction = dir
        source.spectrum = TTCal.PowerLaw(flux.I, 0, 0, 0, 1e6, [0.0])
        subsrc!(data, meta, [source])
    end
    =#

    #=
    model = deepcopy(diffuse)
    for (idx, source) in enumerate(sources_to_peel)
        model′ = genvis(sinebeam, source)
        corrupt!(model′, meta, peelings[idx])
        model.data += model′.data
    end
    if use_sun
        model.data += sun_visibilities.data
    end
    model′ = genvis(meta, sources_to_subtract)
    model.data += model′.data
    =#

    # recalibrate
    #=
    data = deepcopy(original_data)
    data.flags = noflags
    cal = gaincal(data, meta, model, maxiter=30, tolerance=1e-3)
    applycal!(data, meta, cal)

    # remove sources
    data.data -= diffuse.data

    if length(sources_to_peel) ≥ 2
        data.flags = shortflags
        peelings = peel!(GainCalibration, data, sinebeam, sources_to_peel,
                         peeliter=5, maxiter=100, tolerance=1e-3)
    elseif length(sources_to_peel) ≥ 1
        data.flags = shortflags
        peelings = peel!(GainCalibration, data, sinebeam, sources_to_peel,
                         peeliter=1, maxiter=100, tolerance=1e-3)
    end

    if use_sun
        data.flags = shortflags
        sun = fit_shapelets(meta, data, Direction(dir"SUN"), 5, deg2rad(0.2))
        sun_visibilities = genvis(meta, sun)
        data.data -= sun_visibilities.data
    end

    for source in sources_to_subtract
        data.flags = noflags
        dir = fitvis(data, meta, source.direction)
        data.flags = shortflags
        flux = getspec(data, meta, dir) |> mean |> TTCal.stokes
        source.direction = dir
        source.spectrum = TTCal.PowerLaw(flux.I, 0, 0, 0, 1e6, [0.0])
        subsrc!(data, meta, [source])
    end
    =#

    #data.data += diffuse.data
    putdata!(ms, data, true)
    finalize(ms)

    nothing
end

function fit_shapelets(meta, data, dir, nmax, β)
    coeff = zeros((nmax+1)^2)
    rescaling = zeros((nmax+1)^2)
    matrix = zeros(Complex128, Nbase(meta), (nmax+1)^2)
    @time for idx = 1:(nmax+1)^2
        coeff[:] = 0
        coeff[idx] = 1
        source = ShapeletSource("test", dir, PowerLaw(1, 0, 0, 0, 10e6, [0.0]), β, coeff)
        model = genvis(meta, source) # rate limiting step
        for α = 1:Nbase(meta)
            matrix[α,idx] = 0.5*(model.data[α,1].xx + model.data[α,1].yy)
        end
        rescaling[idx] = vecnorm(matrix[:,idx])
        matrix[:,idx] = matrix[:,idx]/rescaling[idx]
    end

    vec = zeros(Complex128, Nbase(meta))
    @time for α = 1:Nbase(meta)
        if meta.baselines[α].antenna1 == meta.baselines[α].antenna2 || data.flags[α,1]
            matrix[α,:] = 0
        else
            vec[α] = 0.5*(data.data[α,1].xx + data.data[α,1].yy)
        end
    end

    matrix = [matrix; conj(matrix)]
    vec    = [vec; conj(vec)]

    A = matrix'*matrix
    b = matrix'*vec
    λ = maximum(eigvals(A))
    A = A + 0.001λ*I
    coeff = real(A\b) ./ rescaling
    @show coeff

    ShapeletSource("test", dir, PowerLaw(1, 0, 0, 0, 10e6, [0.0]), β, coeff)
end

function experiment_with_sidereal_time()
    # test that we can get the sidereal time without having to run dada2ms on everything
    ms1 = dada2ms(1)
    meta1 = getmeta(ms1)
    ms2 = dada2ms(10)
    meta2 = getmeta(ms2)
    t1 = meta1.time.time
    t2 = meta2.time.time
    @show t2 - t1
    @show 663*(10-1)*13
    @show TTCal.position(meta1)
    @show TTCal.position(meta2)
    dump(TTCal.position(meta1))
    nothing
end

function experiment_with_shapelets()
    ms = dada2ms(7)
    meta = getmeta(ms)
    data = getdata(ms)

    noflags = copy(data.flags)
    flag_short_baselines!(data, meta, 15.0)
    shortflags = copy(data.flags)

    # first peel cas and cyg
    data.flags = shortflags
    sources = readsources("cascygsun.json")[1:2]
    peelings = peel!(GainCalibration, data, meta, sources,
                     peeliter=5, maxiter=100, tolerance=1e-3)

    # fit and remove the sun
    data.flags = noflags
    sun = fit_shapelets(meta, data, Direction(dir"SUN"), 5, deg2rad(0.2))
    model = genvis(meta, sun)
    data.data -= model.data

    # now try removing the rfi
    data.flags = shortflags
    rfi = [PointSource("1", Direction(dir"AZEL", "-82d08m38s", "+2d09m28s"),
                       PowerLaw(1, 0, 0, 0, 10e6, [0.0])),
           PointSource("2", Direction(dir"AZEL", "-50d36m09s", "+3d20m20s"),
                       PowerLaw(1, 0, 0, 0, 10e6, [0.0]))]
    peelings = peel!(GainCalibration, data, meta, sources,
                     peeliter=1, maxiter=100, tolerance=1e-3)
    #@show peelings[1].jones

    data.flags = noflags
    putdata!(ms, data)

    #β = deg2rad(5)
    #coeff = [2101.81, 369.81, 1729.89, 42.9875, 622.461, -148.933, 392.566, 405.418, 70.5329, 177.301, 205.334, -100.614, 1954.62, -225.373, 572.859, -139.123, -202.906, -184.796, 461.166, -7.15147, -35.361, -114.897, -22.0132, -63.6195, 1051.63, -276.615, -227.704, 146.901, -52.6569, 20.5867, 390.987, -225.286, -183.02, 50.8521, 41.8813, 19.6081]

    nothing
end

function peel(idx)
    @show idx
    ms = dada2ms(idx)
    meta = getmeta(ms)
    data = getdata(ms)

    sources = readsources("cascygsun.json")
    frame = TTCal.reference_frame(meta)
    flag_short_baselines!(data, meta, 15.0)

    # pick which sources we want to peel
    flux = Float64[]
    sources_to_peel   = TTCal.Source[]
    remaining_sources = TTCal.Source[]
    for source in sources
        newflux = getspec(data, meta, source.direction) |> mean |> TTCal.stokes
        # allowing nonzero Q, U, V is causing problems in calibration
        newflux = StokesVector(newflux.I, 0, 0, 0)
        newspec = PowerLaw(newflux, meta.channels[1], [0.0])
        source.spectrum = newspec
        if newflux.I > 1000
            push!(flux, newflux.I)
            push!(sources_to_peel, source)
        else
            push!(remaining_sources, source)
        end
    end

    # do the peeling
    idx = sortperm(flux, rev=true)
    sources_to_peel = sources_to_peel[idx]
    peelings = peel!(GainCalibration, data, meta, sources_to_peel,
                     peeliter=5, maxiter=100, tolerance=1e-3)

    # pick which sources we want to subtract
    sources_to_subtract = TTCal.Source[]
    final_leftovers     = TTCal.Source[]
    for source in remaining_sources
        newflux = getspec(data, meta, source.direction) |> mean |> TTCal.stokes
        # allowing nonzero Q, U, V is causing problems in calibration
        newflux = StokesVector(newflux.I, 0, 0, 0)
        newspec = PowerLaw(newflux, meta.channels[1], [0.0])
        source.spectrum = newspec
        if newflux.I > 100
            push!(sources_to_subtract, source)
        else
            push!(final_leftovers, source)
        end
    end

    # do the subtraction
    subsrc!(data, meta, sources_to_subtract)

    # output

    #putdata!(ms, data, true)
    putdata!(ms, data)
    nothing
end

function what_was_peeled()
    ms, meta, data = getdata(8)
    frame = TTCal.reference_frame(meta)
    sources = readsources("cascygsun.json")
    peelings = load("peeling-tests/peelings.jld", "peelings")
    sun = sources[3]
    sun.spectrum.stokes = StokesVector(1855.9235979171694,0,0,0)
    gains = peelings[3]
    model = genvis(meta, sun)
    putdata!(ms, model)
end

function image()
    dir = "peeling-tests"
    files = readdir(dir)
    filter!(files) do file
        endswith(file, "ms")
    end
    for file in files[2:4]
        @show file
        ms = joinpath(dir, file)
        img = joinpath(dir, replace(file, ".ms", ""))
        readall(`wsclean -size 4096 4096 -scale 0.03125 -weight natural -name $img $ms`)
    end
end

function simulate_rfi_contribution()
    @time ms = dada2ms(7)
    meta = getmeta(ms)
    sources = load("workspace/info/2016-03-19-01:44:01_0003024944504832.000000/RFI.jld", "rfi")
    @time model = genvis(meta, sources)

    vm = zeros(Complex128, Nbase(meta))
    @time for α = 1:Nbase(meta)
        vm[α] = 0.5*(model.data[α,1].xx + model.data[α,1].yy)
    end

    @time transfermatrix = TransferMatrix("workspace/transfermatrix")
    @time Bm = transfermatrix[0,1]
    @time am = BPJSpec.tikhonov(Bm, vm, 0.05)
    @time vm′ = Bm*am

    alm = Alm(Complex128, transfermatrix.lmax, transfermatrix.mmax)
    BPJSpec.setblock!(alm, am, 0)

    @time for α = 1:Nbase(meta)
        correlation = vm′[α]
        model.data[α,1] = JonesMatrix(correlation, 0, 0, correlation)
    end

    putdata!(ms, model)
    save("peeling-tests/rfi-alm.jld", "alm", alm)
end

function multifrequency_peeling()
    ms1 = Table("peeling-tests/2016-03-19-01:44:01_0000425848971264.000000.ms")
    ms2 = Table("peeling-tests/2016-03-19-01:44:01_0000415136514048.000000.ms")

    #=
    clearflags!(ms1)
    antenna_flags = low_power_antennas(ms1, 1e-1)
    flag_antennas!(antenna_flags, [1; 129]) # broken ARX lines
    flag_antennas!(antenna_flags, 75:79)    # pick-up in ASP rack
    flag_antennas!(antenna_flags, 91:94)    # pick-up in ASP rack
    flag_antennas!(antenna_flags, 186:187)  # unknown
    flag_antennas!(antenna_flags, 247:256)  # LEDA antennas
    #gregg = round(Int, readcsv("gregg.flags"))+1
    #flag_antennas!(antenna_flags, gregg) # Gregg's antenna flags
    applyflags!(ms1, antenna_flags)
    applyflags!(ms2, antenna_flags)

    baseline_flags = zeros(Bool, (256*257)÷2)
    # Flag all the lines on adjacent ARX boards.
    # Note that antennas 287 and 288 use ARX lines 247 and 248, but
    # the correlator sees them as antennas 239 and 240.
    remap = Dict(239 => 247, 240 => 248)
    for ant1 = 1:256, ant2 = ant1:256
        line1 = get(remap, ant1, ant1)
        line2 = get(remap, ant2, ant2)
        if (line1-1) ÷ 8 == (line2-1) ÷ 8 && abs(line1-line2) ≤ 1
            α = baseline_index(ant1, ant2)
            baseline_flags[α] = true
        end
    end
    row_flags = ms1["FLAG_ROW"]
    for α = 1:length(row_flags)
        row_flags[α] = row_flags[α] || baseline_flags[α]
    end
    ms1["FLAG_ROW"] = row_flags
    ms2["FLAG_ROW"] = row_flags
    =#

    sources = readsources("cyg-cas.json")
    meta1 = collect_metadata(ms1, ZernikeBeam())
    meta2 = collect_metadata(ms2, ZernikeBeam())

    data1 = get_data(ms1)
    data2 = get_data(ms2)
    #=
    cal = gaincal(data1, meta1, sources, maxiter=30, tolerance=1e-3)
    applycal!(data2, meta2, cal)
    TTCal.set_data!(ms2, data2)
    =#

    ms = ms2
    data = data2
    meta = meta2
    flag_short_baselines!(data, meta, 15.0)

    shave!(data, meta, sources)

    # Let's see if we can avoid fucking shit up.
    #=
    cal = GainCalibration(Nant(meta), Nfreq(meta))
    model = genvis(meta, sources)
    G = slice(cal.jones, :, 1)
    V, M = TTCal.makesquare(data, model, meta)
    @show converged = TTCal.iterate(TTCal.multistefcalstep, TTCal.RK4, 30, 1e-3, false, G, V, M)
    @show G[1:8]
    for β = 1:Nfreq(meta)
        cal.jones[:,β] = G
    end
    applycal!(data, meta, cal)

    # OK great we have a calibration. Let's do this multifrequency peel.
    Nsource = length(sources)
    calibrations = GainCalibration[GainCalibration(Nant(meta), Nfreq(meta)) for source in sources]
    coherencies = Visibilities[genvis(meta, source) for source in sources]

    for coherency in coherencies
        subsrc!(data, coherency)
    end

    for iter = 1:1
        for s = 1:Nsource
            @show sources[s].name
            coherency = coherencies[s]
            calibration_toward_source = calibrations[s]

            corrupted = deepcopy(coherency)
            corrupt!(corrupted, meta, calibration_toward_source)
            TTCal.putsrc!(data, corrupted)

            G = slice(calibration_toward_source.jones, :, 1)
            V, M = TTCal.makesquare(data, coherency, meta)
            @show converged = TTCal.iterate(TTCal.multistefcalstep, TTCal.RK4, 30, 1e-3, false, G, V, M)
            for β = 1:Nfreq(meta)
                calibration_toward_source.jones[:, β] = G
            end

            corrupted = deepcopy(coherency)
            corrupt!(corrupted, meta, calibration_toward_source)
            subsrc!(data, corrupted)
        end
    end
    #data.flags[:, 2:end] = true
    =#

    set_corrected_data!(ms, data, true)
    nothing
end

end

