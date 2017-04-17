function find_sources(spw, target)
    dir = getdir(spw)
    map = readhealpix(joinpath(dir, target*".fits"))
    psf_dec, psf = load_psf(spw)
    flux, background, residual = _find_sources(map, psf_dec, psf)
    writehealpix(joinpath(dir, "tmp", "flux.fits"), HealpixMap(flux), replace=true)
    writehealpix(joinpath(dir, "tmp", "background.fits"), HealpixMap(background), replace=true)
    writehealpix(joinpath(dir, "tmp", "residual.fits"), HealpixMap(residual), replace=true)
end

function _find_sources(map, psf_dec, psf)
    N = length(map)
    flux = zeros(N)
    background = zeros(N)
    residual = zeros(N)

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
                    flux[mypixel], background[mypixel], residual[mypixel] = take!(output_channel)
                    increment_progress()
                end
            finally
                close(input_channel)
                close(output_channel)
            end
        end
    end
    flux, background, residual
end

function find_sources_remote_processing_loop(input, output, map, psf_dec, psf)
    while true
        try
            pixel = take!(input)
            flux, background, residual = measure_flux(map, psf_dec, psf, pixel)
            put!(output, (flux, background, residual))
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
    dec < minimum(psf_dec) && return 0.0, 0.0, 0.0

    xgrid = linspace(-deg2rad(5.0), +deg2rad(5.0), 201)
    ygrid = linspace(-deg2rad(5.0), +deg2rad(5.0), 201)
    image = extract_image(map, xgrid, ygrid, ra, dec)

    idx = searchsortedlast(psf_dec, dec)
    scale = 1-(dec-psf_dec[idx])
    mypsf = scale*psf[:, :, idx] + (1-scale)*psf[:, :, idx+1]

    image = image[76:126, 76:126]
    mypsf = mypsf[76:126, 76:126]

    measure_flux_do_the_work(image, mypsf)
end

function measure_flux_do_the_work(image, psf)
    N, M = size(image)

    # The goal is to fit the PSF to the given image and measure the flux of a point source (if there
    # is one) at the given location. However, there is a diffuse background that we'd like to
    # account for so we'll add some additional large-scale terms to prevent the diffuse emission
    # from contaminating the flux measurement.
    constant = ones(N*M)
    linear_x = vec([idx for idx = 1:N, jdx = 1:M])
    linear_y = vec([jdx for idx = 1:N, jdx = 1:M])
    quadratic_xx = vec([idx^2 for idx = 1:N, jdx = 1:M])
    quadratic_xy = vec([idx*jdx for idx = 1:N, jdx = 1:M])
    quadratic_yy = vec([jdx^2 for idx = 1:N, jdx = 1:M])

    A = [vec(psf) constant linear_x linear_y quadratic_xx quadratic_xy quadratic_yy]
    b = vec(image)
    x = A\b

    # Discard high residual pixels (these likely contain another bright source).
    δ = b - A*x
    mad  = median(abs(δ))
    keep = δ .< 5mad

    A = A[keep, :]
    b = b[keep]
    x = A\b

    flux = x[1]
    background = x[2]
    residual = vecnorm(b - A*x)/vecnorm(b)
    flux, background, residual
end

