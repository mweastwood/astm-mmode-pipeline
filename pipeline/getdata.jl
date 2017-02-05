function getdata(spw)
    dadas = listdadas(spw)
    getdata(spw, 1, length(dadas))
end

function getdata(spw, start, stop; istest=false)
    Lumberjack.info("Obtaining and calibrating data from spectral window $spw")
    dadas = listdadas(spw)
    sources = readsources(joinpath(sourcelists, "getdata-sources.json"))
    calinfo = readcals(spw)
    meta = getmeta(spw)
    Ntime = length(dadas)

    idx = start
    nextidx() = (myidx = idx; idx += 1; myidx)

    if !istest
        p = Progress(stop - start + 1, "Progress: ")
        l = ReentrantLock()
        increment_progress() = (lock(l); next!(p); unlock(l))

        times = zeros(Ntime)
        data  = zeros(Complex128, 2, Nbase(meta), Ntime)
        flags = zeros(Bool, Nbase(meta), Ntime)
        @sync for worker in workers()
            @async begin
                input = RemoteChannel()
                output_time  = RemoteChannel()
                output_data  = RemoteChannel()
                output_flags = RemoteChannel()
                remotecall(getdata_worker_loop, worker, input, output_time, output_data, output_flags,
                           spw, dadas, sources, calinfo, istest)
                Lumberjack.debug("Worker $worker has been started")
                while true
                    myidx = nextidx()
                    myidx ≤ stop || break
                    Lumberjack.debug("Worker $worker is processing integration $myidx")
                    put!(input, myidx)
                    if !istest
                        times[myidx] = take!(output_time)
                        data[:,:,myidx] = take!(output_data)
                        flags[:,myidx] = take!(output_flags)
                    end
                    increment_progress()
                    gc()
                end
            end
        end
        dir = getdir(spw)
        output_file = joinpath(dir, "visibilities.jld")
        Lumberjack.info("Saving the calibrated data to $output_file")
        save(joinpath(dir, "visibilities.jld"), "times", times, "data", data, "flags", flags)
    else
        while true
            myidx = nextidx()
            myidx ≤ stop || break
            file = dadas[myidx]
            process_integration(spw, file, sources, calinfo, istest)
        end
    end

    nothing
end

function getdata_worker_loop(input, output_time, output_data, output_flags,
                             spw, dadas, sources, calinfo, istest=false)
    while true
        idx = take!(input)
        try
            time, data, flags = process_integration(spw, dadas[idx], sources, calinfo, istest)
            put!(output_time, time)
            put!(output_data, data)
            put!(output_flags, flags)
        catch exception
            println(exception)
        end
    end
end

function process_integration(spw, file, sources, calinfo, istest)
    ms, path = dada2ms(file)
    caltimes, cal = calinfo

    if istest
        @show file
    end

    flag!(ms, spw)
    data = TTCal.read(ms, "DATA")
    meta = Metadata(ms)
    beam = ConstantBeam()
    frame = TTCal.reference_frame(meta)

    # - find the nearest calibration in time and apply it
    time = ms["TIME", 1]
    idx = indmin(abs2(caltimes-time))
    applycal!(data, meta, cal[idx])

    # - flag short baselines
    oldflags = copy(data.flags)
    minuvw = 15.0
    TTCal.flag_short_baselines!(data, meta, minuvw)

    # - begin by classifying the sources based on how we intend to remove them
    sources = TTCal.abovehorizon(frame, sources)
    sources, spectra, directions = update_source_list(data, meta, sources)

    ## - pare down the dataset to just the channel of interest
    β = 55
    ν = meta.channels[β]
    range = β:β
    meta.channels = meta.channels[range]
    data.data  = data.data[:, range]
    data.flags = data.flags[:, range]

    # - decide how we are going to remove each source
    A, B = pick_removal_method(spw, frame, sources, ν)
    #rfi = pick_rfi_sources(spw, data, meta)
    #sun = get_the_sun(spw, data, meta)
    #A = [A; sun]

    if istest
        @show A B
    end

    #empty!(A)
    #empty!(B)

    # - do the source removal
    rfi_flux = rm_rfi(spw, data, meta)
    sun = rm_sun(spw, data, meta)
    coherencies = [genvis(meta, beam, source) for source in A]
    #coherencies = [coherencies; rfi_model]
    calibrations = [GainCalibration(Nant(meta), 1) for idx = 1:length(coherencies)]
    peel!(calibrations, coherencies, data, meta, 5, 30, 1e-3, !istest)
    B, _, _ = update_source_list(data, meta, B)
    subsrc!(data, meta, beam, B)

    # - restore a source as a test
    #idx = 1
    ##coherency = genvis(meta, beam, A[idx])
    #corrupt!(coherencies[idx], meta, calibrations[idx])
    #data.data = coherencies[idx].data

    # - write to the measurement set
    output_visibilities = Visibilities(Nbase(meta), 109)
    output_visibilities.flags[:] = true
    output_visibilities.data[:, 55] = data.data[:, 1]
    output_visibilities.flags[:, 55] = oldflags[:, 55]
    TTCal.write(ms, "DATA", output_visibilities)
    unlock(ms)
    finalize(ms)

    # - output
    #sources, spectra, directions, A, B, calibrations = nothing, nothing, nothing, nothing, nothing, nothing
    getdata_output(spw, path, sources, spectra, directions, A, B, calibrations, rfi_flux, sun, istest)
    rm(path, recursive=true) # note this needs to happen after imaging

    output = zeros(Complex128, 2, Nbase(meta))
    for α = 1:Nbase(meta)
        output[1, α] = data.data[α,1].xx
        output[2, α] = data.data[α,1].yy
    end
    flags = oldflags[:, 55]
    time, output, flags
end

function getdata_output(spw, path, sources, spectra, directions, A, B, calibrations, rfi_flux, sun, istest)
    output = joinpath(getdir(spw), "tmp")
    ms   = basename(path)
    jld  = replace(ms, ".ms", ".jld")
    fits = replace(ms, ".ms", "") # wsclean automatically adds the fits extension
    png  = replace(ms, ".ms", ".png")
    cyg  = "cyg-"*png
    cas  = "cas-"*png
    if istest
        ms   = "test-"*ms
        jld  = "test-"*jld
        fits = "test-"*fits
        png  = "test-"*png
        cyg  = "test-"*cyg
        cas  = "test-"*cas
    end
    ms   = joinpath(output, ms)
    jld  = joinpath(output, jld)
    fits = joinpath(output, fits)
    png  = joinpath(output, png)
    cyg  = joinpath(output, cyg)
    cas  = joinpath(output, cas)

    istest && cp(path, ms, remove_destination=true)

    isfile(jld) && rm(jld)
    save(jld, "sources", sources, "spectra", spectra, "directions", directions,
         "A", A, "B", B, "calibrations", calibrations, "rfi_flux", rfi_flux, "sun", sun)
    
    wsclean(path, fits)
    lower, upper = -100, +200
    fits2png(fits, png, lower, upper)
    wcs = wcs_from_fits(fits*".fits")
    annotate(png, wcs, [(19+59/60+28/3600)*15, (40+44/60+02/3600)]) # Cyg A
    annotate(png, wcs, [(23+23/60+24/3600)*15, (58+48/60+54/3600)]) # Cas A
    crop(png, cyg, wcs, [(19+59/60+28/3600)*15, (40+44/60+02/3600)]) # Cyg A
    crop(png, cas, wcs, [(23+23/60+24/3600)*15, (58+48/60+54/3600)]) # Cas A
    if !istest
        rm(fits*".fits")
    end

    nothing
end

function pick_removal_method(spw, frame, sources, ν)
    A = TTCal.Source[]
    B = TTCal.Source[]
    fluxes = Float64[]
    for source in sources
        flux = StokesVector(TTCal.get_total_flux(source, ν)).I
        flux > 30 || continue
        if source.name == "Cyg A" || source.name == "Cas A"
            if TTCal.isabovehorizon(frame, source, deg2rad(10))
                push!(A, source)
                push!(fluxes, flux)
            else
                push!(B, source)
            end
        elseif source.name == "Vir A"# || source.name == "Tau A"
            if TTCal.isabovehorizon(frame, source, deg2rad(45))
                push!(A, source)
                push!(fluxes, flux)
            else
                push!(B, source)
            end
        else
            push!(B, source)
        end
    end
    perm = sortperm(fluxes, rev=true)
    A = A[perm]
    A, B
end

function rm_rfi(spw, data, meta)
    #models = load(joinpath(getdir(spw), "rfi-models.jld"), "models") :: Vector{Visibilities}
    #N = length(models)
    #A = zeros(Complex128, 2Nbase(data), N)
    #b = zeros(Complex128, 2Nbase(data))
    ##A = zeros(Complex128, Nbase(data), N)
    ##b = zeros(Complex128, Nbase(data))
    #α = 1
    #for ant1 = 1:Nant(meta), ant2 = ant1:Nant(meta)
    #    if !data.flags[α, 1] && ant1 != ant2
    #        for idx = 1:N
    #            #A[α, idx] = models[idx].data[α, 1].xx
    #            A[2α-1, idx] = models[idx].data[α, 1].xx
    #            A[2α-0, idx] = conj(models[idx].data[α, 1].xx)
    #        end
    #        #b[α] = data.data[α, 1].xx
    #        b[2α-1] = data.data[α, 1].xx
    #        b[2α-0] = conj(data.data[α, 1].xx)
    #    end
    #    α += 1
    #end
    #x = real(A\b)
    #@show x
    #xx = A*x
    #@show real(A\(b-xx))
    #α = 1
    #for ant1 = 1:Nant(meta), ant2 = ant1:Nant(meta)
    #    if !data.flags[α, 1] && ant1 != ant2
    #        for idx = 1:N
    #            #A[α, idx] = models[idx].data[α, 1].yy
    #            A[2α-1, idx] = models[idx].data[α, 1].yy
    #            A[2α-0, idx] = conj(models[idx].data[α, 1].yy)
    #        end
    #        #b[α] = data.data[α, 1].yy
    #        b[2α-1] = data.data[α, 1].yy
    #        b[2α-0] = conj(data.data[α, 1].yy)
    #    end
    #    α += 1
    #end
    #y = real(A\b)
    #@show y
    #yy = A*y
    #@show real(A\(b-yy))
    #for α = 1:Nbase(data)
    #    #J = JonesMatrix(xx[α], 0, 0, yy[α])
    #    J = JonesMatrix(xx[2α-1], 0, 0, yy[2α-1])
    #    data.data[α, 1] -= J
    #end
    #0.5*(x+y)
    if spw == 18
        N = 3
    else
        N = 0
    end
    dir = getdir(spw)
    fluxes = zeros(HermitianJonesMatrix, N)
    #models = Array{Visibilities}(N)
    for idx = 1:N
        #model = models[idx]
        model = load(joinpath(dir, "old-rfi", "rfi-$idx.jld"), "model") :: Visibilities
        spectrum = zeros(HermitianJonesMatrix, 1)
        TTCal.getspec_internal!(spectrum, data, meta, model.data)
        J = spectrum[1]
        #I = StokesVector(J).I
        #Jd = DiagonalJonesMatrix(J.xx, J.yy)
        #@show J I
        #@show model.data[258, 1]
        for α = 1:Nbase(meta)
            # TODO I can't decide if we need to multiply on the left or the right here
            # if we make sure the model doesn't carry any polarization information than it shouldn't matter
            model.data[α, 1] = J * model.data[α, 1]
        end
        subsrc!(data, model)
        fluxes[idx] = J
        #models[idx] = model
    end
    #fluxes, models
    fluxes
end

#function pick_rfi_sources(spw, data, meta)
#    A = ShavingSource[]
#    positions = [Position(pos"WGS84",
#                          1226.7091391887516meters,
#                          -118.3147833410907degrees,
#                          37.145402389570144degrees),
#                 Position(pos"WGS84",
#                          1214.248326037079meters,
#                          -118.3852914162684degrees,
#                          37.3078474772316degrees),
#                 Position(pos"WGS84",
#                          1232.6294581335637meters,
#                          -118.36229648059934degrees,
#                          37.24861167954518degrees),
#                 Position(pos"WGS84",
#                          1608.21583019197meters,
#                          -118.23417138204732degrees,
#                          37.06249388547446degrees)]
#    #Position(pos"WGS84", 1232.7690506698564meters, -118.37296747772183degrees, 37.24935118263112degrees),
#    for (idx, position) in enumerate(positions)
#        spectrum = RFISpectrum(meta.channels, fill(StokesVector(1, 0, 0, 0), length(meta.channels)))
#        source = RFISource("RFI $('A'+idx-1)", position, spectrum)
#        flux = getflux(data, meta, source)
#        #if flux > 300
#        #    spectrum = RFISpectrum(meta.channels, fill(StokesVector(flux, 0, 0, 0), length(meta.channels)))
#        #    source = RFISource("RFI $('A'+idx-1)", position, spectrum)
#        #    push!(A, ShavingSource(source))
#        #end
#        push!(A, ShavingSource(source))
#    end
#    A
#end

function rm_sun(spw, data, meta)
    frame = TTCal.reference_frame(meta)
    sun = fit_shapelets("Sun", meta, data, Direction(dir"SUN"), 5, deg2rad(0.2))
    model = genvis(meta, ConstantBeam(), sun)
    subsrc!(data, model)
    sun
end

function get_the_sun(spw, data, meta)
    A = TTCal.Source[]
    frame = TTCal.reference_frame(meta)
    if TTCal.isabovehorizon(frame, Direction(dir"SUN"))
        sun = fit_shapelets("Sun", meta, data, Direction(dir"SUN"), 5, deg2rad(0.2))
        push!(A, sun)
        #solar_flux = getflux(data, meta, Direction(dir"SUN"))
        #if solar_flux > 100
        #    suntimes, suns = readsuns(spw)
        #    idx = indmin(abs2(suntimes-time))
        #    sun = suns[idx]
        #    push!(A, ShavingSource(sun))
        #end
    end
    A
end

# SOURCE REMOVAL

#function check_peeling_convergence(data, meta, original_sources, updated_sources, fluxes, calibrations)
#    N = length(original_sources)
#    bad = fill(false, N)
#    newfluxes = Float64[getflux(data, meta, source) for source in original_sources]
#    for idx = 1:N
#        original_sources[idx].name == "Sun" && continue
#        startswith(original_sources[idx].name, "RFI") && continue
#        if abs(newfluxes[idx]) > 0.10*abs(fluxes[idx])
#            bad[idx] = true
#            model = genvis(meta, updated_sources[idx])
#            corrupt!(model, meta, calibrations[idx])
#            putsrc!(data, model)
#        end
#    end
#    failed = original_sources[bad]
#    sources = updated_sources[!bad]
#    calibrations = calibrations[!bad]
#    failed, sources, calibrations
#end

#function do_peeling!(data, meta, beam, sources, istest)
#    #updated_sources, spectra, directions = update_source_list(data, meta, sources)
#    #istest && @show updated_sources
#    calibrations = peel!(data, meta, beam, updated_sources, peeliter=5, maxiter=30, tolerance=1e-3, quiet=!istest)
#    calibrations#, updated_sources, spectra, directions
#end
#
#function do_subtraction!(data, meta, beam, sources)
#    #updated_sources, spectra, directions = update_source_list(data, meta, sources)
#    subsrc!(data, meta, beam, updated_sources)
#    #updated_sources, spectra, directions
#end

# SOURCE FITTING

function update_source_list(data, meta, sources)
    N = length(sources)
    mysources = similar(sources)
    myspectra = Vector{Vector{HermitianJonesMatrix}}(N)
    mydirections = Vector{Direction}(N)
    myflux = Vector{Float64}(N)
    for (idx, source) in enumerate(sources)
        #@show TTCal.unwrap(source).name
        _source, _spec, _dir = update(data, meta, source)
        _flux = Float64[0.5*(_spec[idx].xx+_spec[idx].yy) for idx = 1:length(_spec)]
        mysources[idx] = _source
        myspectra[idx] = _spec
        mydirections[idx] = _dir
        myflux[idx] = mean(_flux)
    end
    permutation = sortperm(myflux, rev=true)
    mysources = mysources[permutation]
    myspectra = myspectra[permutation]
    mydirections = mydirections[permutation]
    mysources, myspectra, mydirections
end

function getflux(data, meta, source)
    spec = getspec(data, meta, source)
    I = Float64[0.5*(spec[idx].xx+spec[idx].yy) for idx = 1:length(spec)]
    mean(I)
end

function update(data, meta, source::Union{PeelingSource, ShavingSource})
    source = deepcopy(source)
    direction = updatedirection!(data, meta, source.source)
    spectrum = updateflux!(data, meta, source.source)
    source, spectrum, direction
end

function update(data, meta, source::TTCal.Source)
    source = deepcopy(source)
    direction = updatedirection!(data, meta, source)
    spectrum = updateflux!(data, meta, source)
    source, spectrum, direction
end

function updateflux!(data::Visibilities, meta, source)
    spec = getspec(data, meta, source)
    updateflux!(spec, meta, source)
    spec
end

function updateflux!(spec::Vector{HermitianJonesMatrix}, meta, source)
    modelspec = [TTCal.get_total_flux(source, ν) for ν in meta.channels]
    modelI = Float64[0.5*(modelspec[idx].xx+modelspec[idx].yy) for idx = 1:length(spec)]
    I      = Float64[0.5*(     spec[idx].xx+     spec[idx].yy) for idx = 1:length(spec)]
    Q      = Float64[0.5*(     spec[idx].xx-     spec[idx].yy) for idx = 1:length(spec)]
    scale = (modelI \ I)[1]
    polarization_fraction = (I \ Q)[1]
    #polarization_fraction *= -1 # THIS SIGN FLIP IS NECESSARY TO MATCH WSCLEAN
    #polarization_fraction = 0
    scaleflux!(source, scale, polarization_fraction)
end

function updateflux!(spec::Vector{HermitianJonesMatrix}, meta, source::RFISource)
    stokes = StokesVector.(spec)
    spectrum = TTCal.RFISpectrum(meta.channels, stokes)
    source.spectrum = spectrum
end

function scaleflux!(source, scale, polarization_fraction)
    I = source.spectrum.stokes.I
    source.spectrum.stokes = StokesVector(I*scale, I*scale*polarization_fraction, 0, 0)
end

function scaleflux!(source::MultiSource, scale, polarization_fraction)
    for component in source.components
        scaleflux!(component, scale, polarization_fraction)
    end
end

function updatedirection!(data::Visibilities, meta, source) :: Direction
    if source.name == "SUN"
        return Direction(dir"SUN") :: Direction
    else
        #direction = fancy_pants_direction_fitting(data, meta, source)
        direction = fitvis(data, meta, source, tolerance=1e-5) :: Direction
        frame = TTCal.reference_frame(meta)
        changedirection!(source, frame, direction)
        return direction
    end
end

function updatedirection!(data::Visibilities, meta, source::RFISource) :: Direction
    # RFI sources are fixed, so return a sentinal
    Direction(dir"AZEL", 0degrees, 90degrees)
end

changedirection!(source, frame, direction) = source.direction = direction
function changedirection!(source::MultiSource, frame, direction)
    original = measure(frame, TTCal.get_mean_direction(frame, source), dir"J2000")
    Δx = direction.x - original.x
    Δy = direction.y - original.y
    Δz = direction.z - original.z
    for component in source.components
        mydirection = component.direction
        x = mydirection.x + Δx
        y = mydirection.y + Δy
        z = mydirection.z + Δz
        norm = sqrt(x^2 + y^2 + z^2)
        component.direction = Direction(dir"J2000", x/norm, y/norm, z/norm)
    end
end

function fancy_pants_direction_fitting(data, meta, source)
    frame = TTCal.reference_frame(meta)
    dir0 = measure(frame, TTCal.get_mean_direction(frame, source), dir"J2000")
    rhat = [dir0.x, dir0.y, dir0.z]
    north = [0, 0, 1]
    north = north - dot(rhat, north)*rhat
    north = north / norm(north)
    east  = cross(north, rhat)

    #=
    # 1. Fit for the location of the source
    #    * begin by measuring the flux at a grid of points
    #    * start `fitvis` at the grid point with the highest flux
    θgrid = linspace(0, 2π, 7)[1:6]
    rgrid = deg2rad(linspace(10, 60, 3)/60)
    dirs = Direction[]
    fluxes = Float64[]
    push!(dirs, dir0) # don't forget to include the central spot!
    for r in rgrid, θ in θgrid
        vec = rhat + r*cos(θ)*north + r*sin(θ)*east
        vec = vec / norm(vec)
        dir = Direction(dir"J2000", vec[1], vec[2], vec[3])
        push!(dirs, dir)
        changedirection!(source, frame, dir)
        push!(fluxes, getflux(data, meta, source))
    end
    @show dirs fluxes
    idx = indmax(fluxes)
    @show dirs[idx]
    dir = fitvis(data, meta, dirs[idx], maxiter=10, tolerance=1e-3)
    #dir = dirs[idx]
    @show dir
    =#
    dir = fitvis(data, meta, dir0, tolerance=1e-4) # maxiter doesn't do anything right now

    # revert to the old best direction if fitvis diverged
    Δθ = acosd(dir.x*dir0.x + dir.y*dir0.y + dir.z*dir0.z)
    if Δθ > 1 || !TTCal.isabovehorizon(frame, dir)
        dir = dirs[idx]
    end
    dir
end

function getpointmodel(data, meta, source)
    frame = TTCal.reference_frame(meta)
    dir0 = measure(frame, TTCal.get_mean_direction(frame, source), dir"J2000")
    rhat = [dir0.x, dir0.y, dir0.z]
    north = [0, 0, 1]
    north = north - dot(rhat, north)*rhat
    north = north / norm(north)
    east  = cross(north, rhat)

    # 1. Fit for the location of the source
    #    * begin by measuring the flux at a grid of points
    #    * start `fitvis` at the grid point with the highest flux
    θgrid = linspace(0, 2π, 7)[1:6]
    rgrid = deg2rad(linspace(10, 60, 3)/60)
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

    # 2. Measure the spectrum of the source
    #    * measure the Stokes I and Stokes Q flux at each frequency channel
    #    * fit a power law to the spectrum
    ν = mean(meta.channels)
    spec = getspec(data, meta, dir)
    I = Float64[0.5*(spec[idx].xx+spec[idx].yy) for idx = 1:length(spec)]
    Q = Float64[0.5*(spec[idx].xx-spec[idx].yy) for idx = 1:length(spec)]
    keep = I .> 0
    I = I[keep]
    Q = Q[keep]
    if length(I) == 0
        a = 0.0
        b = 0.0
        pfrac = 0.0
    else
        x = log10(meta.channels[keep]) - log10(ν)
        y = log10(I)
        a, b = linreg(x, y)
        pfrac = mean(Q./I) # the polarization fraction
    end
    spec = PowerLaw(StokesVector(10^a, pfrac*10^a, 0, 0), ν, [b])

    PointSource(source.name, dir, spec)
end

