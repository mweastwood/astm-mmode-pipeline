module Driver

using CasaCore.Tables
using CasaCore.Measures
using LibHealpix
using MLPFlagger
using TTCal
using BPJSpec
using JLD
using ProgressMeter
using NPZ
using Interpolations
using NLopt
using FITSIO
using FileIO

# 6628 integrations per sidereal day (assuming 13 s integrations).
const Ntime = 6628

# Gregg's favorite channel is #48 in subband 16.
const subband = 16
const channel = 48

const tempdir = "/dev/shm/mweastwood"

const dir = "/lustre/data/2016-03-19_100hour_run"
const files = readdir(joinpath(dir, "00")) |> sort
filter!(files) do file
    startswith(file, "2016-03-19-01:44:01")
end
const day1 = files[       1: Ntime]
const day2 = files[ Ntime+1:2Ntime]
const day3 = files[2Ntime+1:3Ntime]
const day4 = files[3Ntime+1:   end]

baseline_index(ant1, ant2) = div((ant1-1)*(512-(ant1-2)), 2) + (ant2-ant1+1)

include("pipeline/dada2ms.jl")
include("pipeline/wsclean.jl")
include("pipeline/flags.jl")
include("pipeline/getalm.jl")
include("pipeline/getmodelmmodes.jl")
include("pipeline/getmodeldata.jl")
include("pipeline/residualsvd.jl")

function gettimes()
    output = open("times.txt", "w")
    for file in files
        time = readall(`dada_filename_time.py -i 13 $file`)
        write(output, @sprintf("%s    %s", file, time))
    end
    close(output)
end

function fits2png(input, output)
    fits = FITS(input*".fits")
    img = read(fits[1])[:,:,1,1]
    lower_limit = -300
    upper_limit = +800
    img -= lower_limit
    img /= upper_limit - lower_limit
    img = clamp(img, 0, 1)
    img = flipdim(img', 1)
    save(output*".png", img)
end

function getbeam_woody(frequency = 67.752)
    mountain_az, mountain_el = load("workspace/beam/mountain-elevation.jld", "az", "el")
    mountain_az = deg2rad(mountain_az)
    mountain_el = deg2rad(mountain_el)
    mountain = interpolate((mountain_az,), mountain_el, Gridded(Linear()))

    woody = readdlm("workspace/beam/DW_beamquadranttable20151110.txt", skipstart=7)
    θgrid = 0:5:90
    ϕgrid = 0:5:90
    νgrid = 20:10:80

    co = complex(woody[:,4], woody[:,5])
    cx = complex(woody[:,6], woody[:,7])
    cogrid = reshape(co, length(θgrid), length(ϕgrid), length(νgrid))
    cxgrid = reshape(cx, length(θgrid), length(ϕgrid), length(νgrid))
    stokesIgrid = abs2(cogrid) + abs2(cxgrid)
    interp = interpolate((θgrid, ϕgrid, νgrid), stokesIgrid, Gridded(Linear()))

    ms = Table("workspace/calibrations/day1.ms")
    meta = collect_metadata(ms, ConstantBeam())
    frame = TTCal.reference_frame(meta)
    position = measure(frame, TTCal.position(meta), pos"ITRF")
    zenith = BPJSpec.normalize!([position.x, position.y, position.z])
    north  = BPJSpec.gramschmidt([0.0, 0.0, 1.0], zenith)
    east   = cross(north, zenith)
    nside = 1024
    map = HealpixMap(Float64, nside)
    for pix = 1:length(map)
        vec = LibHealpix.pix2vec_ring(nside, pix)
        el = π/2 - BPJSpec.angle_between(vec, zenith)
        x  = dot(vec, east)
        y  = dot(vec, north)
        az = atan2(x, y)
        # check to see where the horizon is at this azimuth
        threshold = mountain[mod2pi(az)]
        if el < threshold
            map[pix] = 0
        else
            θ = rad2deg(π/2 - el)
            ϕ = rad2deg(az)
            ϕ <  0 && (ϕ = -ϕ)
            ϕ > 90 && (ϕ = 180-ϕ)
            map[pix] = interp[θ, ϕ, frequency] + interp[θ, 90-ϕ, frequency]
        end
    end

    map = HealpixMap(map.pixels / maximum(map.pixels))
    writehealpix("workspace/beam/beam-map.fits", map, replace=true)

    nothing
end

function getbeam_michael()
    coeff = [0.5925713994750834,-0.4622486219893028,-0.054924184973998307,-0.0028805328944419696,-0.02407776673368796,-0.006155457593922782,-0.023973603224075223,-0.003090132046373044,0.00497413312773207]

    mountain_az, mountain_el = load("workspace/beam/mountain-elevation.jld", "az", "el")
    mountain_az = deg2rad(mountain_az)
    mountain_el = deg2rad(mountain_el)
    mountain = interpolate((mountain_az,), mountain_el, Gridded(Linear()))

    ms = Table("workspace/calibrations/day1.ms")
    meta = collect_metadata(ms, ConstantBeam())
    frame = TTCal.reference_frame(meta)
    position = measure(frame, TTCal.position(meta), pos"ITRF")
    zenith = BPJSpec.normalize!([position.x, position.y, position.z])
    north  = BPJSpec.gramschmidt([0.0, 0.0, 1.0], zenith)
    east   = cross(north, zenith)
    nside = 1024
    map = HealpixMap(Float64, nside)
    for pix = 1:length(map)
        vec = LibHealpix.pix2vec_ring(nside, pix)
        el = π/2 - BPJSpec.angle_between(vec, zenith)
        x  = dot(vec, east)
        y  = dot(vec, north)
        az = atan2(x, y)
        ρ = cos(el)
        θ = az
        # check to see where the horizon is at this azimuth
        threshold = mountain[mod2pi(az)]
        if el < threshold
            map[pix] = 0
        else
            map[pix] = (coeff[1]*zernike(0, 0, ρ, θ)
                        + coeff[2]*zernike(2, 0, ρ, θ)
                        + coeff[3]*zernike(4, 0, ρ, θ)
                        + coeff[4]*zernike(4, 4, ρ, θ)
                        + coeff[5]*zernike(6, 0, ρ, θ)
                        + coeff[6]*zernike(6, 4, ρ, θ)
                        + coeff[7]*zernike(8, 0, ρ, θ)
                        + coeff[8]*zernike(8, 4, ρ, θ)
                        + coeff[9]*zernike(8, 8, ρ, θ))
        end
    end

    map = HealpixMap(map.pixels / maximum(map.pixels))
    writehealpix("workspace/beam/beam-map.fits", map, replace=true)

    nothing
end

function read_meta_from_ms(ms)
    meta = collect_metadata(ms, ConstantBeam())
    meta.channels = meta.channels[channel:channel]
    meta
end

function read_data_from_ms(ms)
    data = TTCal.get_data(ms)
    data.data  = data.data[:,channel:channel]
    data.flags = data.flags[:,channel:channel]
    data
end

function write_data_to_ms!(ms, data, flags=false)
    N = (256*257)÷2
    expanded_data = Visibilities(zeros(JonesMatrix, N, 109), fill(true, N, 109))
    expanded_data.data[:,channel] = data.data
    expanded_data.flags[:,channel] = data.flags
    TTCal.set_corrected_data!(ms, expanded_data, true)
    TTCal.set_flags!(ms, expanded_data)
end

function getcal(input, output)
    isdir("workspace/calibrations") || mkdir("workspace/calibrations")
    cal_name  = joinpath("workspace/calibrations", output*".jld")
    ms_name   = joinpath("workspace/calibrations", output*".ms")
    dada_name = joinpath(dir, @sprintf("%02d", subband), input)
    dada2ms(dada_name, ms_name)
    ms = Table(ascii(ms_name))
    begin
        info("Flagging")
        clearflags!(ms)
        apply_antenna_flags!(ms)
        apply_baseline_flags!(ms)
    end
    begin
        info("Calibrating")
        sources = readsources("cyg-cas.json")
        data = get_data(ms)
        meta = collect_metadata(ms, Memo178Beam())
        flag_short_baselines!(data, meta, 15.0)

        # Do an initial calibration.
        cal = gaincal(data, meta, sources, maxiter=30, tolerance=1e-3)
        applycal!(data, meta, cal)

        # Peel Cyg and Cas
        peelings = peel!(data, meta, sources, peeliter=3, maxiter=30, tolerance=1e-3)

        # Apply Cyg's calibration to set the flux scale
        applycal!(data, meta, peelings[1])

        # Output.
        set_corrected_data!(ms, data)
        save(cal_name, "cal1", cal, "cal2", peelings[1])
    end

    unlock(ms)
end

function getcal()
    # TODO: use multiple integrations to help mitigate the effects of
    #       scintillation on the flux scale
    integration = 3698 # 8:00 am (15:00 UTC time)
    try
        getcal(day1[integration], "day1")
        getcal(day2[integration], "day2")
        getcal(day3[integration], "day3")
        getcal(day4[integration], "day4")
    finally
        gc(); gc()
    end
end

function imagecal()
    wsclean("workspace/calibrations/day1")
    wsclean("workspace/calibrations/day2")
    wsclean("workspace/calibrations/day3")
    wsclean("workspace/calibrations/day4")
end

function read_cal(path)
    cal = load(path, "cal")
    cal
end

function getdata()
    files = day1
    ms = Table("workspace/calibrations/day1.ms")
    meta = read_meta_from_ms(ms)
    calibration = "workspace/calibrations/day1.jld"
    output = "workspace/visibilities-day1"
    getdata(files, meta, calibration, output)

    files = day2
    ms = Table("workspace/calibrations/day2.ms")
    meta = read_meta_from_ms(ms)
    calibration = "workspace/calibrations/day2.jld"
    output = "workspace/visibilities-day2"
    getdata(files, meta, calibration, output)

    files = day3
    ms = Table("workspace/calibrations/day3.ms")
    meta = read_meta_from_ms(ms)
    calibration = "workspace/calibrations/day3.jld"
    output = "workspace/visibilities-day3"
    getdata(files, meta, calibration, output)

    files = day4
    ms = Table("workspace/calibrations/day4.ms")
    meta = read_meta_from_ms(ms)
    calibration = "workspace/calibrations/day4.jld"
    output = "workspace/visibilities-day4"
    getdata(files, meta, calibration, output)
end

function getdata(files, meta, calibration, output)
    visibilities = GriddedVisibilities(output, meta, Ntime)
    cal1, cal2 = load(calibration, "cal1", "cal2")

    idx = 1
    limit = length(files)
    nextidx() = (myidx = idx; idx += 1; myidx)

    p = Progress(length(files), "Progress: ")
    l = ReentrantLock()
    increment_progress() = (lock(l); next!(p); unlock(l))

    @sync for worker in workers()
        @async while true
            myidx = nextidx()
            myidx ≤ limit || break
            mymeta, mydata = remotecall_fetch(process_integration, worker, files[myidx], cal1, cal2)
            grid!(visibilities, mymeta, mydata)
            increment_progress()
        end
    end
    nothing
end

function interpolate_visibilities(origin, model_visibilities, meta)
    Nbase, Ntime = size(model_visibilities)
    output = Visibilities(fill(one(JonesMatrix), Nbase, 1), fill(false, Nbase, 1))
    Δt = 1/Ntime
    times = 0.0:Δt:(1.0-Δt)
    time = mod(BPJSpec.sidereal_time(meta) - origin, 1)
    idx1 = searchsortedlast(times, time)
    idx2 = idx1 == Ntime? 1 : idx1+1
    weight1 = 1 - (time - times[idx1])/Δt
    weight2 = 1 - weight1 # note this handles the case where the second grid point has wrapped around
    for α = 1:Nbase
        correlation = weight1*model_visibilities[α,idx1] + weight2*model_visibilities[α,idx2]
        output.data[α,1] = JonesMatrix(correlation, 0, 0, correlation)
    end
    output
end

function fit_shapelets(meta, data, dir, nmax, β)
    coeff = zeros((nmax+1)^2)
    rescaling = zeros((nmax+1)^2)
    matrix = zeros(Complex128, Nbase(meta), (nmax+1)^2)
    for idx = 1:(nmax+1)^2
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
    for α = 1:Nbase(meta)
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

    ShapeletSource("test", dir, PowerLaw(1, 0, 0, 0, 10e6, [0.0]), β, coeff)
end

function fit_rfi(meta, data)
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

    sources = TTCal.RFISource[]
    for idx = 1:length(rfi)
        position = rfi[idx]
        spectrum = TTCal.RFISpectrum(meta.channels, [StokesVector(flux[idx], 0, 0, 0)])
        source = TTCal.RFISource("RFI", position, spectrum)
        push!(sources, source)
    end
    sources
end

function process_integration(file, cal1, cal2)
    ms, path = dada2ms(file)
    local meta, data
    try
        clearflags!(ms)
        apply_antenna_flags!(ms)
        apply_baseline_flags!(ms)

        data = get_data(ms)
        meta = collect_metadata(ms, Memo178Beam())
        frame = TTCal.reference_frame(meta)
        applycal!(data, meta, cal1)
        applycal!(data, meta, cal2)
        oldflags = copy(data.flags)
        flag_short_baselines!(data, meta, 15.0)

        cygcas = TTCal.abovehorizon(frame, readsources("cyg-cas.json"))
        tauvir = TTCal.abovehorizon(frame, readsources("tau-vir.json"))
        for source in [cygcas; tauvir]
            measure_source!(source, data, meta)
        end
        filter!(cygcas) do source
            source.spectrum.stokes.I > 500
        end
        fluxes = [source.spectrum.stokes.I for source in cygcas]
        filter!(tauvir) do source
            any(source.spectrum.stokes.I .> fluxes)
        end

        sources = [cygcas; tauvir]
        fluxes = [source.spectrum.stokes.I for source in sources]
        idx = sortperm(fluxes, rev=true)
        sources = sources[idx]

        shavings = shave!(data, meta, sources, quiet=true)
        for idx = 1:length(sources)
            source = sources[idx]
            if source.name == "Tau A" || source.name == "Vir A"
                model = genvis(meta, source)
                corrupt!(model, meta, shavings[idx])
                data.data += model.data
            end
        end

        data.flags = oldflags
        set_corrected_data!(ms, data)
        TTCal.set_flags!(ms, data)

        # Output
        outputdir = joinpath("workspace/info", replace(file, ".dada", ""))
        isdir(outputdir) || mkdir(outputdir)
        for (idx,source) in enumerate(sources)
            outputfile = joinpath(outputdir, replace(source.name, " ", "")*".jld")
            JLD.save(outputfile, "source", source, "gains", shavings[idx])
        end
    catch err
        @show file
        throw(err)
    finally
        unlock(ms)
        finalize(ms)
        gc(); gc()
    end

    outputdir = joinpath("workspace/info", replace(file, ".dada", ""))
    output = joinpath(outputdir, "image")
    wsclean(path, output)
    rm(path, recursive=true)

    meta.channels = meta.channels[channel:channel]
    data.data  = data.data[:,channel:channel]
    data.flags = data.flags[:,channel:channel]
    meta, data
end

function movie()
    dirs = readdir("workspace/info")
    filter!(dirs) do dir
        startswith(dir, "2016-03-19-01:44:01")
    end

    idx = 1
    limit = length(dirs)
    nextidx() = (myidx = idx; idx += 1; myidx)

    p = Progress(length(files), "Converting: ")
    l = ReentrantLock()
    increment_progress() = (lock(l); next!(p); unlock(l))

    @sync for worker in workers()
        @async while true
            myidx = nextidx()
            myidx ≤ limit || break
            remotecall_fetch(create_frame, worker, myidx, dirs[myidx])
            increment_progress()
        end
    end

    run(`ffmpeg -start_number 1 -i workspace/movie/%05d.png -codec:v libx264 -profile:v high444 -preset slow -b:v 2000k -vf scale=-1:720 workspace/movie/movie.mp4`)
end

function create_frame(idx, dir)
    input = joinpath("workspace/info", dir, "image")
    output = joinpath("workspace/movie", @sprintf("%05d", idx))
    fits2png(input, output)
    nothing
end

function combinedays()
    visibilities_day1 = GriddedVisibilities("workspace/visibilities-day1")
    visibilities_day2 = GriddedVisibilities("workspace/visibilities-day2")
    visibilities_day3 = GriddedVisibilities("workspace/visibilities-day3")
    visibilities_day4 = GriddedVisibilities("workspace/visibilities-day4")
    info("Day 1")
    day1 = visibilities_day1[1]
    info("Day 2")
    day2 = visibilities_day2[1]
    info("Day 3")
    day3 = visibilities_day3[1]
    info("Day 4")
    day4 = visibilities_day4[1]
    ν = visibilities_day1.frequencies
    origin = visibilities_day1.origin
    Nbase, Ntime = size(day1)
    output = zeros(Complex128, Nbase, Ntime)
    for t = 1:Ntime
        @show t
        for ant1 = 1:256, ant2 = ant1:256
            α = baseline_index(ant1, ant2)
            values = Complex128[]
            day1[α,t] != 0 && push!(values, day1[α,t])
            day2[α,t] != 0 && push!(values, day2[α,t])
            day3[α,t] != 0 && push!(values, day3[α,t])
            day4[α,t] != 0 && push!(values, day4[α,t])
            if length(values) > 0
                output[α,t] = complex(median(real(values)), median(imag(values)))
            end
        end
    end
    info("Output")
    visibilities = GriddedVisibilities("workspace/visibilities-combined", Nbase, Ntime, ν, origin)
    for t = 1:Ntime, α = 1:Nbase
        visibilities.data[1][α,t] = output[α,t]
        visibilities.weights[1][α,t] = 1.0
    end
end

function getmmodes()
    #visibilities = GriddedVisibilities("workspace/visibilities-combined-svd-rfi-suppression")
    visibilities = GriddedVisibilities("workspace/visibilities-rfi-free")
    ## flag the known bad integrations
    #visibilities.data[1][:,106:110] = 0
    #visibilities.data[1][:,119:128] = 0
    ## flag the autocorrelations
    #for ant = 1:256
    #    α = baseline_index(ant, ant)
    #    visibilities.data[1][α,:] = 0
    #end
    #mmodes = MModes("workspace/mmodes-svd-rfi-suppression", visibilities, 1000)
    #mmodes = MModes("workspace/mmodes", visibilities, 1000)
    mmodes = MModes("workspace/mmodes-rfi-free", visibilities, 1000)
    nothing
end

function flagmmodes()
    input = MModes("workspace/mmodes-svd-rfi-suppression")
    output = MModes("workspace/mmodes-svd-rfi-suppression-flagged", input.mmax, input.frequencies)
    for m = 0:1000
        block = input[m,1]
        really_bad = (1, 73, 75, 76, 77, 78, 79, 88, 91, 92, 93, 94, 105, 106, 121, 129, 146, 149, 158, 162, 165, 169, 186, 187, 190, 198, 221, 226, 247, 248, 249, 250, 251, 252, 253, 254, 255, 256)
        suspicious = (44, 45, 199, 200, 210, 211)
        for ant1 = 1:256, ant2 = ant1:256
            flag = ant1 == ant2 # flag the auto-correlations
            flag = flag || (m ≤ 1) && (ant1-1)÷8 == (ant2-1)÷8 # flag lines that share an ARX board
            flag = flag || (ant1 in really_bad || ant2 in really_bad) # flag antennas that are really bad
            flag = flag || (ant1 in suspicious || ant2 in suspicious) # flag suspicious antennas
            if flag
                α = baseline_index(ant1, ant2)
                if m == 0
                    block[α] = 0
                else
                    block[2α-1] = 0
                    block[2α-0] = 0
                end
            end
        end
        output[m,1] = block
    end
    # old record of suspicious antennas
    #suspicious = (44, 45, 115, 116, 117, 118, 119)
end

function gettransfermatrix()
    lmax = mmax = 1000
    ms = Table("workspace/calibrations/day1.ms")
    meta = read_meta_from_ms(ms)
    beam = readhealpix("workspace/beam/beam-map.fits")
    transfermatrix = TransferMatrix("workspace/transfermatrix", meta, beam, lmax, mmax, 1024)
    nothing
end

#=
function getalm(tolerance, input, output)
    mmodes = MModes("workspace/$input")
    transfermatrix = TransferMatrix("workspace/transfermatrix")
    alm = tikhonov(transfermatrix, mmodes, tolerance)
    save("workspace/$output.jld", "alm", alm)
    # Cteate a map in J2016 coordinates.
    ms = Table("workspace/calibrations/day1.ms")
    meta = collect_metadata(ms, ConstantBeam())
    frame = TTCal.reference_frame(meta)
    map = alm2map(alm, 2048)
    # Convert to temperature units (Kelvin).
    map = map * (BPJSpec.Jy * (BPJSpec.c/mmodes.frequencies[1])^2 / (2*BPJSpec.k))
    # Rotate the map to galactic coordinates.
    newmap = HealpixMap(Float64, 2048)
    galactic_z = Direction(dir"GALACTIC", 0.0degrees, 90degrees)
    galactic_z_in_itrf = measure(frame, galactic_z, dir"ITRF")
    galactic_x = Direction(dir"GALACTIC", 0.0degrees, 0.0degrees)
    galactic_x_in_itrf = measure(frame, galactic_x, dir"ITRF")
    z = [galactic_z_in_itrf.x, galactic_z_in_itrf.y, galactic_z_in_itrf.z]
    x = [galactic_x_in_itrf.x, galactic_x_in_itrf.y, galactic_x_in_itrf.z]
    y = cross(z, x)
    p = Progress(length(newmap), "Rotating: ")
    for i = 1:length(newmap)
        vec = LibHealpix.pix2vec_ring(nside(newmap), i)
        vec′ = vec[1]*x + vec[2]*y + vec[3]*z
        j = LibHealpix.vec2pix_ring(nside(newmap), vec′)
        newmap[i] = map[j]
        next!(p)
    end
    writehealpix("workspace/$output.fits", newmap, replace=true)
    nothing
end
=#

function source_fluxes()
    dirs = readdir("workspace/info")
    filter!(dirs) do dir
        startswith(dir, "2016-03-19-01:44:01")
    end

    Nant  = 256
    Ntime = length(dirs)

    # first two columns will store az/el
    # third column will store flux if source was subtracted
    # one column for each antenna if the source was peeled
    cyg_a = zeros(Ntime, 2+Nant)
    cas_a = zeros(Ntime, 2+Nant)
    vir_a = zeros(Ntime, 3)
    tau_a = zeros(Ntime, 3)
    her_a = zeros(Ntime, 3)
    hya_a = zeros(Ntime, 3)
    per_b = zeros(Ntime, 3)
    rfi = zeros(Ntime, 4) # one column for each RFI source

    t0 = 4.965068647500005e9
    lwa = Position(pos"ITRF", -2.40927462614919e6, -4.477838733582964e6, 3.839370728766106e6)

    p = Progress(Ntime, "Progress: ")
    for idx = 1:Ntime
        #frame = ReferenceFrame()
        #t = Epoch(epoch"UTC", t0 + (idx-1)*13)
        #set!(frame, t)
        #set!(frame, lwa)

        dir = dirs[idx]
        path = joinpath("workspace/info", dir)
        #vir_a[idx,:] = read_subtracted_source(frame, joinpath(path, "VirA.jld"))
        #tau_a[idx,:] = read_subtracted_source(frame, joinpath(path, "TauA.jld"))
        #her_a[idx,:] = read_subtracted_source(frame, joinpath(path, "HerA.jld"))
        #hya_a[idx,:] = read_subtracted_source(frame, joinpath(path, "HyaA.jld"))
        #per_b[idx,:] = read_subtracted_source(frame, joinpath(path, "PerB.jld"))
        rfi[idx,:] = read_rfi_sources(joinpath(path, "RFI.jld"))

        next!(p)
    end

    #writedlm("workspace/info/VirA.txt", vir_a)
    #writedlm("workspace/info/TauA.txt", tau_a)
    #writedlm("workspace/info/HerA.txt", her_a)
    #writedlm("workspace/info/HyaA.txt", hya_a)
    #writedlm("workspace/info/PerB.txt", per_b)
    writedlm("workspace/info/RFI.txt", rfi)
end

function read_subtracted_source(frame, filename)
    if !isfile(filename)
        return [0.0, 0.0, 0.0]
    end
    source = load(filename, "source")
    azel = measure(frame, source.direction, dir"AZEL")
    az = longitude(azel)
    el =  latitude(azel)
    flux = source.spectrum.stokes.I
    [az, el, flux]
end

function read_rfi_sources(filename)
    sources = load(filename, "rfi")
    Float64[source.spectrum.stokes[1].I for source in sources]
end

function fit_beam()
    vir_a = readdlm("workspace/info/VirA.txt")
    tau_a = readdlm("workspace/info/TauA.txt")
    her_a = readdlm("workspace/info/HerA.txt")
    hya_a = readdlm("workspace/info/HyaA.txt")
    per_b = readdlm("workspace/info/PerB.txt")

    mountain_az, mountain_el = load("workspace/beam/mountain-elevation.jld", "az", "el")
    mountain_az = deg2rad(mountain_az)
    mountain_el = deg2rad(mountain_el)
    mountain = interpolate((mountain_az,), mountain_el, Gridded(Linear()))

    radius  = Vector{Float64}[]
    azimuth = Vector{Float64}[]
    flux    = Vector{Float64}[]
    for src in (vir_a, tau_a, her_a, hya_a, per_b)
        az = src[:,1]
        el = src[:,2]
        I  = src[:,3]
        l = sin(az).*cos(el)
        m = cos(az).*cos(el)

        keep = fill(true, size(src,1))
        for idx = 1:size(src,1)
            if I[idx] == l[idx] == m[idx] == 0
                keep[idx] = false
            elseif el[idx] < mountain[az[idx]]
                # source is below the mountains
                keep[idx] = false
            elseif idx != 1
                # weed out some of the garbage
                if abs(I[idx] - I[idx-1]) > 0.25*abs(I[idx])
                    keep[idx] = false
                elseif hypot(l[idx] - l[idx-1], m[idx] - m[idx-1]) > 0.1
                    keep[idx] = false
                end
            end
        end
        l = l[keep]
        m = m[keep]
        I = I[keep]

        #l′ = [l; l; -l; -l; m; m; -m; -m]
        #m′ = [m; -m; m; -m; l; -l; l; -l]
        #I′ = [I; I; I; I; I; I; I; I]

        #r = sqrt(l′.^2 + m′.^2)
        #θ = atan2(l′, m′)
        r = sqrt(l.^2 + m.^2)
        θ = atan2(l, m)

        push!(radius, r)
        push!(azimuth, θ)
        #push!(flux, I′)
        push!(flux, I)
    end

    function chi_squared(x, g)
        @show x
        N = length(flux)
        χ2 = 0.0
        my_fluxes = x[1:N]
        my_params = x[N+1:end]
        for idx = 1:N
            F = flux[idx]
            r = radius[idx]
            θ = azimuth[idx]
            for jdx = 1:length(F)
                # only use Zernike polynomials with the allowed symmetries
                beam = (my_params[1]*zernike(0, 0, r[jdx], θ[jdx])
                            + my_params[2]*zernike(2, 0, r[jdx], θ[jdx])
                            + my_params[3]*zernike(4, 0, r[jdx], θ[jdx])
                            + my_params[4]*zernike(4, 4, r[jdx], θ[jdx])
                            + my_params[5]*zernike(6, 0, r[jdx], θ[jdx])
                            + my_params[6]*zernike(6, 4, r[jdx], θ[jdx])
                            + my_params[7]*zernike(8, 0, r[jdx], θ[jdx])
                            + my_params[8]*zernike(8, 4, r[jdx], θ[jdx])
                            + my_params[9]*zernike(8, 8, r[jdx], θ[jdx]))
                χ2 += abs2(F[jdx] - my_fluxes[idx]*beam)
            end
        end
        χ2
    end

    function normalization(x, g)
        N = length(flux)
        my_params = x[N+1:end]
        r = θ = 0
        beam = (my_params[1]*zernike(0, 0, r, θ)
                    + my_params[2]*zernike(2, 0, r, θ)
                    + my_params[3]*zernike(4, 0, r, θ)
                    + my_params[4]*zernike(4, 4, r, θ)
                    + my_params[5]*zernike(6, 0, r, θ)
                    + my_params[6]*zernike(6, 4, r, θ)
                    + my_params[7]*zernike(8, 0, r, θ)
                    + my_params[8]*zernike(8, 4, r, θ)
                    + my_params[9]*zernike(8, 8, r, θ))
        beam - 1
    end

    info("Starting optimization")
    opt = Opt(:LN_COBYLA, length(flux) + 9)
    min_objective!(opt, chi_squared)
    equality_constraint!(opt, normalization)
    xtol_rel!(opt, 1e-4)

    x0 = [1958.1094106281766,1535.8584327761537,851.9310060559844,608.5844805870518,399.87660844402563,0.5925713994750834,-0.4622486219893028,-0.054924184973998307,-0.0028805328944419696,-0.02407776673368796,-0.006155457593922782,-0.023973603224075223,-0.003090132046373044,0.00497413312773207]
    minf, x, ret = optimize(opt, x0)

    @show x
    params = x[length(flux)+1:end]

    # image the results (and compare it with sin^1.6 and Woody beam models)
    woody = readdlm("workspace/beam/DW_beamquadranttable20151110.txt", skipstart=7)
    θgrid = 0:5:90
    ϕgrid = 0:5:90
    νgrid = 20:10:80
    co = complex(woody[:,4], woody[:,5])
    cx = complex(woody[:,6], woody[:,7])
    cogrid = reshape(co, length(θgrid), length(ϕgrid), length(νgrid))
    cxgrid = reshape(cx, length(θgrid), length(ϕgrid), length(νgrid))
    stokesIgrid = abs2(cogrid) + abs2(cxgrid)
    interp = interpolate((θgrid, ϕgrid, νgrid), stokesIgrid, Gridded(Linear()))

    img1 = zeros(1000, 1000)
    img2 = zeros(1000, 1000)
    img3 = zeros(1000, 1000)
    l = linspace(-1, 1, 1000)
    m = linspace(-1, 1, 1000)
    for j = 1:length(m), i = 1:length(l)
        r = hypot(l[i], m[j])
        r ≥ 1 && continue
        θ = atan2(l[i], m[j])
        az = π/2 - θ
        el = acos(r)
        az <   0 && (az = -az)
        az > π/2 && (az = π-az)
        beam = (params[1]*zernike(0, 0, r, θ)
                    + params[2]*zernike(2, 0, r, θ)
                    + params[3]*zernike(4, 0, r, θ)
                    + params[4]*zernike(4, 4, r, θ)
                    + params[5]*zernike(6, 0, r, θ)
                    + params[6]*zernike(6, 4, r, θ)
                    + params[7]*zernike(8, 0, r, θ)
                    + params[8]*zernike(8, 4, r, θ)
                    + params[9]*zernike(8, 8, r, θ))
        img1[i,j] = sin(el)^1.6
        img2[i,j] = interp[rad2deg(π/2-el), rad2deg(az), 67.752] + interp[rad2deg(π/2-el), rad2deg(π/2-az), 67.752]
        img3[i,j] = beam
    end
    img2 /= maximum(img2)

    save("workspace/beam/beam-comparisons.jld", "img1", img1, "img2", img2, "img3", img3)
end

function zernike(n, m, ρ, θ)
    zernike_radial_part(n, abs(m), ρ) * zernike_azimuthal_part(m, θ)
end

function zernike_radial_part(n, m, ρ)
    R0 = ρ^m
    n == m && return R0
    R2 = ((m+2)*ρ^2 - (m+1))*R0
    for n′ = m+4:2:n
        # TODO: n needs to be n′
        recurrence_relation = (2*(n-1)*(2n*(n-2)*ρ^2-m^2-n*(n-2))*R2 - n*(n+m-2)*(n-m-2)*R0) / ((n+m)*(n-m)*(n-2))
        R0 = R2
        R2 = recurrence_relation
    end
    R2
end

function zernike_azimuthal_part(m, θ)
    if m == 0
        return 1.0
    elseif m > 0
        return cos(m*θ)
    else
        return sin(m*θ)
    end
end

function is_this_zernike_polynomial_allowed(n, m)
    # roll 100 random points and see if it has the right symmetries
    for i = 1:100
        ρ = rand()
        θ = 2π*rand()

        z1 = zernike(n, m, ρ, θ)
        z2 = zernike(n, m, ρ, θ+π/2)
        z3 = zernike(n, m, ρ, θ+π)
        z4 = zernike(n, m, ρ, θ+3π/2)
        z5 = zernike(n, m, ρ, -θ)
        z6 = zernike(n, m, ρ, -θ+π/2)
        z7 = zernike(n, m, ρ, -θ+π)
        z8 = zernike(n, m, ρ, -θ+3π/2)

        if !(z1 ≈ z2 ≈ z3 ≈ z4 ≈ z5 ≈ z6 ≈ z7 ≈ z8)
            return false
        end
    end
    true
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

function getmodelvis()
    ms = Table("workspace/calibrations/day1.ms")
    meta = read_meta_from_ms(ms)
    unlock(ms)

    #alm = load("workspace/alm.jld", "alm")
    #alm = load("workspace/blotted-alm.jld", "alm")
    alm = load("workspace/alm-lots-of-flags.jld", "alm")
    transfermatrix = TransferMatrix("workspace/transfermatrix")
    mmodes = MModes("workspace/model-mmodes", transfermatrix, alm)
    visibilities = GriddedVisibilities("workspace/model-visibilities", meta, mmodes, 6628)
    nothing
end

function backup_images()
    dirs = readdir("workspace/info")
    filter!(dirs) do dir
        startswith(dir, "2016-03-19-01:44:01")
    end

    for idx in (770, 1717, 2044, 2146, 2333, 2589, 3029, 3605, 3803, 4672, 4955)
        path = joinpath("workspace/info", dirs[idx], "image.fits")
        cp(path, joinpath("workspace/image-backup", dirs[idx]*"-before.fits"))
    end
end

function test_getdata()
    files = ByteString[]
    #for idx in (770, 1717, 2044, 2146, 2333, 2589, 3029, 3605, 3803, 4672, 4955)
    #for idx in (770,)
    for idx in (1:600:6628)
        push!(files, day1[idx])
    end
    #calibration = read_cal("workspace/calibrations/day1.jld")
    cal1, cal2 = load("workspace/calibrations/day1.jld", "cal1", "cal2")

    for file in files
        test_process_integration(file, cal1, cal2)
    end
    nothing
end

function test_process_integration(file, cal1, cal2)
    ms, path = dada2ms(file)
    local meta, data
    try
        clearflags!(ms)
        apply_antenna_flags!(ms)
        apply_baseline_flags!(ms)

        data = get_data(ms)
        meta = collect_metadata(ms, ConstantBeam())
        frame = TTCal.reference_frame(meta)
        applycal!(data, meta, cal1)
        applycal!(data, meta, cal2)
        oldflags = copy(data.flags)
        flag_short_baselines!(data, meta, 15.0)

        cygcas = TTCal.abovehorizon(frame, readsources("cyg-cas.json"))
        tauvir = TTCal.abovehorizon(frame, readsources("tau-vir.json"))
        for source in [cygcas; tauvir]
            measure_source!(source, data, meta)
        end
        filter!(cygcas) do source
            source.spectrum.stokes.I > 500
        end
        fluxes = [source.spectrum.stokes.I for source in cygcas]
        filter!(tauvir) do source
            any(source.spectrum.stokes.I .> fluxes)
        end

        sources = [cygcas; tauvir]
        fluxes = [source.spectrum.stokes.I for source in sources]
        idx = sortperm(fluxes, rev=true)
        sources = sources[idx]

        shavings = shave!(data, meta, sources)
        for idx = 1:length(sources)
            source = sources[idx]
            if source.name == "Tau A" || source.name == "Vir A"
                model = genvis(meta, source)
                corrupt!(model, meta, shavings[idx])
                @show size(model.data) size(data.data)
                data.data += model.data
                println("got here")
            end
        end

        data.flags = oldflags
        set_corrected_data!(ms, data)
        TTCal.set_flags!(ms, data)

        #=
        data = read_data_from_ms(ms)
        meta = read_meta_from_ms(ms)
        meta.beam = ConstantBeam()
        ν = meta.channels[1]
        frame = TTCal.reference_frame(meta)
        applycal!(data, meta, calibration)
        oldflags = copy(data.flags)
        flag_short_baselines!(data, meta, 15.0)

        # Pick the sources to peel and subtract.
        sources = readsources("sources.json")
        sources_to_peel = TTCal.Source[]
        sources_to_peel_flux = Float64[]
        sources_to_subtract = TTCal.Source[]
        sources_to_subtract_flux = Float64[]
        for source in sources
            dir0 = source.direction
            azel = measure(frame, dir0, dir"AZEL")
            el   = latitude(azel) |> rad2deg
            el < 0 && continue

            # Define a grid of directions.
            # The goal here is to help start `fitvis` close to the actual location of
            # the source because if we start it too far away, it might fail.
            lat  =  latitude(dir0) |> rad2deg
            long = longitude(dir0) |> rad2deg
            θgrid = linspace(0, 2π, 9)[1:8]
            dirs = Direction[Direction(dir"J2000", (long + (5/60)*cos(θ))*degrees,
                                                   ( lat + (5/60)*sin(θ))*degrees) for θ in θgrid]
            push!(dirs, dir0) # don't forget to include the central spot!
            fluxes = Float64[TTCal.stokes(getspec(data, meta, dir)[1]).I for dir in dirs]
            idx = indmax(fluxes)

            # Fit for the location and flux of the source.
            dir = fitvis(data, meta, dirs[idx])
            stokes = TTCal.stokes(getspec(data, meta, dir)[1])

            if stokes.I > 5000
                source.direction = dir
                source.spectrum.stokes = StokesVector(stokes.I, stokes.Q, 0, 0)
                source.spectrum.ν = ν
                source.spectrum.α = [0.0]
                push!(sources_to_peel, source)
                push!(sources_to_peel_flux, stokes.I)
            else
                push!(sources_to_subtract, source)
                push!(sources_to_subtract_flux, stokes.I)
            end
        end

        # Do the peeling.
        println("Peeling")
        idx = sortperm(sources_to_peel_flux, rev=true)
        sources_to_peel = sources_to_peel[idx]
        @show sources_to_peel
        if length(sources_to_peel) ≥ 2
            peelings = peel!(GainCalibration, data, meta, sources_to_peel,
                             peeliter=3, maxiter=100, tolerance=1e-3, quiet=false)
        elseif length(sources_to_peel) ≥ 1
            peelings = peel!(GainCalibration, data, meta, sources_to_peel,
                             peeliter=1, maxiter=100, tolerance=1e-3, quiet=false)
        end

        # Construct the diffuse sky model.
        #diffuse = interpolate_visibilities(origin, model_visibilities, meta)
        =#

        #=
        # Remove the sun.
        direction_to_sun = Direction(dir"SUN")
        if TTCal.isabovehorizon(frame, direction_to_sun)
            use_sun = true
            sun = fit_shapelets(meta, data, direction_to_sun, 5, deg2rad(0.2))
            sun_visibilities = genvis(meta, sun)
            data.data -= sun_visibilities.data
        else
            use_sun = false
        end

        # Fit and remove the horizon RFI.
        #rfi = fit_rfi(meta, data)
        #rfi_visibilities = genvis(meta, rfi)
        #data.data -= rfi_visibilities.data

        # Subtract the remaining sources.
        # Get a new position and flux for each source now that most of the bright
        # stuff is removed.
        println("Subtracting")
        idx = sortperm(sources_to_subtract_flux, rev=true)
        sources_to_subtract = sources_to_subtract[idx]
        for source in sources_to_subtract
            println("-----")
            # Define a grid of directions.
            # The goal here is to help start `fitvis` close to the actual location of
            # the source because if we start it too far away, it might fail.
            dir0 = source.direction
            lat  =  latitude(dir0) |> rad2deg
            long = longitude(dir0) |> rad2deg
            θgrid = linspace(0, 2π, 9)[1:8]
            dirs = Direction[Direction(dir"J2000", (long + (5/60)*cos(θ))*degrees,
                                                   ( lat + (5/60)*sin(θ))*degrees) for θ in θgrid]
            push!(dirs, dir0) # don't forget to include the central spot!
            fluxes = Float64[TTCal.stokes(getspec(data, meta, dir)[1]).I for dir in dirs]
            idx = indmax(fluxes)
            @show fluxes
            @show dirs

            # Fit for the location and flux of the source.
            dir = fitvis(data, meta, dirs[idx])
            stokes = TTCal.stokes(getspec(data, meta, dir)[1])

            # Do the subtraction.
            ra = sexagesimal(mod2pi(longitude(dir)), hours=true)
            dec = sexagesimal(latitude(dir))
            @show source.name stokes.I ra dec
            source.direction = dir
            source.spectrum.stokes = StokesVector(stokes.I, stokes.Q, 0, 0)
            source.spectrum.ν = ν
            source.spectrum.α = [0.0]
            subsrc!(data, meta, [source])
            println("-----")
        end
        =#

        #data.flags = oldflags
        #write_data_to_ms!(ms, data)
    catch e
        @show file
        throw(e)
    finally
        unlock(ms)
        finalize(ms)
        gc(); gc()

        outputdir = joinpath("workspace/image-backup")
        output = joinpath(outputdir, replace(file, ".dada", ""))
        wsclean(path, output)

        @show path
        #rm(path, recursive=true)
    end
    #meta, data
end

function measure_source!(source, data, meta)
    # Define a grid of directions.
    # The goal here is to help start `fitvis` close to the actual location of
    # the source because if we start it too far away, it might fail.
    frame = TTCal.reference_frame(meta)
    dir0 = source.direction
    rhat = [dir0.x, dir0.y, dir0.z]
    north = [0, 0, 1]
    north = north - dot(rhat, north)*rhat
    north = north / norm(north)
    east  = cross(north, rhat)
    θgrid = linspace(0, 2π, 9)[1:8]
    rgrid = deg2rad(linspace(5, 25, 3)/60)
    dirs = Direction[]
    push!(dirs, dir0) # don't forget to include the central spot!
    for r in rgrid, θ in θgrid
        vec = rhat + r*cos(θ)*north + r*sin(θ)*east
        vec = vec / norm(vec)
        dir = Direction(dir"J2000", vec[1], vec[2], vec[3])
        push!(dirs, dir)
    end
    fluxes = Float64[TTCal.stokes(mean(getspec(data, meta, dir))).I for dir in dirs]
    idx = indmax(fluxes)
    dir = fitvis(data, meta, dirs[idx])

    # Fit a power law to the spectrum
    ν = mean(meta.channels)
    spec = getspec(data, meta, dir)
    I = [0.5*(spec[idx].xx+spec[idx].yy) for idx = 1:length(spec)]
    if any(I .< 0)
        a = 0.0
        b = 0.0
    else
        x = log10(meta.channels) - log10(ν)
        y = log10(I)
        a, b = linreg(x, y)
    end

    source.direction = dir
    source.spectrum.stokes = StokesVector(10^a, 0, 0, 0)
    source.spectrum.ν = ν
    source.spectrum.α = [b]
end

end

