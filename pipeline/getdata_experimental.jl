function getdata_experimental(spw, start, stop, istest=false)
    dadas = listdadas(spw)
    sources = readsources(joinpath(sourcelists, "getdata-sources.json"))
    calinfo = readcals(spw)
    meta = getmeta(spw)

    idx = start
    nextidx() = (myidx = idx; idx += 1; myidx)

    p = Progress(stop - start + 1, "Progress: ")
    l = ReentrantLock()
    increment_progress() = (lock(l); next!(p); unlock(l))

    if !istest
        Ntime = length(dadas)
        times = zeros(Ntime)
        flags = zeros(Bool, Nbase(meta), Ntime)
        data  = zeros(Complex128, Nbase(meta), Ntime)
    end

    @sync for worker in workers()
        @async while true
            myidx = nextidx()
            myidx ≤ stop || break
            mytime, mydata, myflags = remotecall_fetch(process_integration_experimental, worker,
                                                       spw, dadas, sources, calinfo, myidx, istest)
            if !istest
                times[myidx] = mytime
                data[:, myidx] = mydata
                flags[:, myidx] = myflags
            end
            increment_progress()
        end
    end

    if !istest
        save(joinpath(getdir(spw), "experimental-visibilities.jld"), "times", times, "data", data, "flags", flags)
    end

    nothing
end

function process_integration_experimental(spw, dadas, sources, calinfo, integration, istest)
    Ntime = length(dadas)
    day = 6628 # number of integrations per sidereal day
    beam = ConstantBeam()

    dada_filename = dadas[integration]
    ms_filename = joinpath(tempdir, replace(basename(dada_filename), "dada", "ms"))
    fits_filename = replace(ms_filename, ".ms", "") # wsclean automatically adds the fits extension
    png_filename  = replace(ms_filename, ".ms", ".png")

    dada2ms_core(dada_filename, ms_filename)
    ms = Table(ms_filename)
    flag!(ms, spw)
    visibilities = TTCal.read(ms, "DATA")
    meta = Metadata(ms)
    frame = TTCal.reference_frame(meta)

    # Calibrate
    caltimes, calibrations = calinfo
    time = ms["TIME", 1]
    calibration = calibrations[indmin(abs2(caltimes-time))]
    applycal!(visibilities, meta, calibration)

    # Flag short baselines
    old_flags = deepcopy(visibilities.flags)
    TTCal.flag_short_baselines!(visibilities, meta, 15.0)

    # Update the source models
    sources = filter(sources) do source
        if source.name == "Cyg A" || source.name == "Cas A" || source.name == "Vir A"
            if TTCal.isabovehorizon(frame, source)
                # We'll just do a straight subtraction below some flux level
                flux = getflux(visibilities, meta, source)
                return flux > 700
            end
        end
        false
    end
    rfi = RFISource("RFI C",
                    #Position(pos"WGS84", 1232.7690506698564meters, -118.37296747772183degrees, 37.24935118263112degrees),
                    Position(pos"WGS84", 1232.6294581335637meters, -118.36229648059934degrees, 37.24861167954518degrees),
                    RFISpectrum(meta.channels, fill(StokesVector(1, 0, 0, 0), length(meta.channels))))
    rfiflux = getflux(visibilities, meta, rfi)
    if rfiflux > 500
        push!(sources, rfi)
    end

    suntimes, suns = readsuns(spw)
    idx = indmin(abs2(suntimes-time))
    push!(sources, suns[idx])

    sources, spectra, directions = update_source_list(visibilities, meta, sources)

    if istest
        @show sources
    end

    ## Pare down the data set
    #n = 1 # total number of points is 2^n + 1
    #N = n == 0? 0 : 2^(n-1)
    N = 0
    mid = round(Int, middle(1:Nfreq(meta)))
    range = mid-N:mid+N
    meta.channels = meta.channels[range]
    visibilities.data  = visibilities.data[:, range]
    visibilities.flags = visibilities.flags[:, range]

    # Compute the coherencies
    coherencies = [genvis(meta, beam, source) for source in sources]

    ## Weight the visibilities
    #σ = N/2
    #weights = exp.(-(range .- mid).^2 ./ (2σ^2))
    #for β = 1:Nfreq(meta), α = 1:Nbase(meta)
    #    visibilities.data[α, β] *= weights[β]
    #end
    #for coherency in coherencies
    #    for β = 1:Nfreq(meta), α = 1:Nbase(meta)
    #        coherency.data[α, β] *= weights[β]
    #    end
    #end

    # Peel the sources from the data set
    calibrations = [GainCalibration(Nant(meta), 1) for source in sources]
    solutions = peel!(calibrations, coherencies, visibilities, meta, 5, 30, 1e-3, true)

    # temporarily restore the model of cas
    #idx = 2
    #corrupt!(coherencies[idx], meta, solutions[idx])
    #visibilities.data = coherencies[idx].data

    ## Pare down the data set even further to the only channel we're interested in
    #mid = round(Int, middle(1:Nfreq(meta)))
    #range = mid:mid
    #meta.channels = meta.channels[range]
    #visibilities.data  = visibilities.data[:, range]
    #visibilities.flags = visibilities.flags[:, range]

    # Write the visibilities to the measurement set and image
    output_visibilities = Visibilities(Nbase(meta), 109)
    output_visibilities.flags[:] = true
    output_visibilities.data[:, 55] = visibilities.data
    output_visibilities.flags[:, 55] = old_flags[:, 55]
    TTCal.write(ms, "DATA", output_visibilities)
    finalize(ms)
    wsclean(ms_filename, fits_filename)
    fits2png(fits_filename, png_filename, -100, 200)
    cyg_png_filename, cas_png_filename = annotate(fits_filename)

    # Delete all the temporary files
    if !istest
        rm(ms_filename, recursive=true)
        rm(fits_filename*".fits")
        rm(png_filename)
        mv(cyg_png_filename, joinpath(getdir(spw), "tmp", basename(cyg_png_filename)), remove_destination=true)
        mv(cas_png_filename, joinpath(getdir(spw), "tmp", basename(cas_png_filename)), remove_destination=true)
    end

    # Output the relevant data
    flags = output_visibilities.flags[:, 55]
    jones = output_visibilities.data[:, 55]
    scalar = zeros(Complex128, Nbase(meta))
    for α = 1:Nbase(meta)
        scalar[α] = 0.5*(jones[α].xx + jones[α].yy)
    end
    time, scalar, flags
end

function wcs_from_fits(filename)
    fits = FITS(filename)
    header = read_header(fits[1])
    WCSTransform(2; cdelt = [header["CDELT1"], header["CDELT2"]],
                    ctype = [header["CTYPE1"], header["CTYPE2"]],
                    crpix = [header["CRPIX1"], header["CRPIX2"]],
                    crval = [header["CRVAL1"], header["CRVAL2"]])
end

function annotate(filename)
    wcs = wcs_from_fits(filename*".fits")
    png = filename*".png"
    annotate(png, wcs, [(19+59/60+28/3600)*15, (40+44/60+02/3600)]) # Cyg A
    annotate(png, wcs, [(23+23/60+24/3600)*15, (58+48/60+54/3600)]) # Cas A
    cyg = joinpath(dirname(png), "cyg-"*basename(png))
    cas = joinpath(dirname(png), "cas-"*basename(png))
    crop(png, cyg, wcs, [(19+59/60+28/3600)*15, (40+44/60+02/3600)]) # Cyg A
    crop(png, cas, wcs, [(23+23/60+24/3600)*15, (58+48/60+54/3600)]) # Cas A
    cyg, cas
end

function annotate(png, wcs, coords)
    pix = world_to_pix(wcs, coords) 
    pix = [pix[1], 2048 - pix[2]]
    run(`convert $png -fill none -stroke red -strokewidth 1 -draw "circle $(pix[1]),$(pix[2]) $(pix[1]+10),$(pix[2]+10)" $png`)
end

function crop(input, output, wcs, coords)
    pix = world_to_pix(wcs, coords)
    pix = [pix[1], 2048 - pix[2]]
    width = [512, 512]*sqrt(2)
    side1 = max(0, pix[1]-width[1]/2)
    side2 = max(0, pix[2]-width[2]/2)
    run(`convert $input -crop $(width[1])x$(width[2])+$(side1)+$(side2) $output`)
end

