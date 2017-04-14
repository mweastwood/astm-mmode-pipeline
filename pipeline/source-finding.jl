function find_sources(spw, target)
    dir = getdir(spw)
    map = readhealpix(joinpath(dir, target*".fits"))
    psf_dec, psf = load_psf(spw)

    #meta = getmeta(spw, "rainy")
    #frame = TTCal.reference_frame(meta)
    #dir = Direction(dir"J2000", "01h37m41.2971s", "+33d09m35.118s") # 3C 48
    #dir = measure(frame, dir, dir"ITRF")
    #θ = π/2 - latitude(dir)
    #ϕ = longitude(dir)
    #pixel = LibHealpix.ang2pix_ring(nside(map), θ, ϕ)
    #measure_flux(map, psf_dec, psf, pixel)

    flux, background = _find_sources(map, psf_dec, psf)
end

function _find_sources(map, psf_dec, psf)
    N = length(map)
    flux = zeros(N)
    background = zeros(N)

    pixel = 1
    next_pixel() = (pixel′ = pixel; pixel += 1; pixel′)
    prg = Progress(N, "Progress: ")
    lck = ReentrantLock()
    increment_progress() = (lock(lck); next!(prg); unlock(lck))
    @sync for worker in workers()
        @async begin
            input_channel  = RemoteChannel()
            output_channel = RemoteChannel()
            try
                remotecall(find_sources_remote_processing_loop, worker, input_channel, output_channel,
                           map, psf_dec, psf)
                Lumberjack.debug("Worker $worker has been started")
                while true
                    mypixel = next_pixel()
                    mypixel ≤ N || break
                    Lumberjack.debug("Worker $worker is processing pixel=$mypixel")
                    put!(input_channel, mypixel)
                    flux[mypixel], background[mypixel] = take!(output_channel)
                    increment_progress()
                end
            finally
                close(input_channel)
                close(output_channel)
            end
        end
    end
    flux, background
end

function find_sources_remote_processing_loop(input, output, map, psf_dec, psf)
    while true
        try
            pixel = take!(input)
            flux, background = measure_flux(map, psf_dec, psf, pixel)
            put!(output, (flux, background))
        catch exception
            if isa(exception, RemoteException) || isa(exception, InvalidStateException)
                # If this is a remote worker, we will see a RemoteException when the channel is
                # closed. However, if this is the master process (ie. we're running without any
                # workers) then this will be an InvalidStateException. This is kind of messy...
                break
            else
                println(exception)
                rethrow(exception)
            end
        end
    end
end

function measure_flux(map, psf_dec, psf, pixel)
    θ, ϕ = LibHealpix.pix2ang_ring(nside(map), pixel)
    ra, dec = ϕ, π/2-θ

    xgrid = linspace(-deg2rad(5.0), +deg2rad(5.0), 201)
    ygrid = linspace(-deg2rad(5.0), +deg2rad(5.0), 201)
    image = extract_image(map, xgrid, ygrid, ra, dec)

    dec < minimum(psf_dec) && return 0.0, 0.0
    idx = searchsortedlast(psf_dec, dec)
    scale = 1-(dec-psf_dec[idx])
    mypsf = scale*psf[:, :, idx] + (1-scale)*psf[:, :, idx+1]

    flux, background = measure_flux_do_the_work(image[76:126, 76:126], mypsf[76:126, 76:126])
    flux, background
end

function measure_flux_do_the_work(image, psf)
    A = [vec(psf) ones(length(psf))]
    b = vec(image)
    x = A\b

    flux = x[1]
    background = x[2]
    flux, background
end

