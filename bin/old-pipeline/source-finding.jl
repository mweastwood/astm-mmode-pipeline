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
    mypsf = interpolate_psf(psf_dec, psf, dec)

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

function find_sources_in_the_map(spw, target)
    dir = getdir(spw)
    map = readhealpix(joinpath(dir, target*".fits"))
    flux = readhealpix(joinpath(dir, "tmp", "flux.fits"))
    meta = getmeta(18, "rainy")
    frame = TTCal.reference_frame(meta)

    regions = select_regions(flux, 64)
    #for region in regions
    #    vec = LibHealpix.pix2vec_ring(nside(flux), first(region))
    #    itrf = Direction(dir"ITRF", vec[1], vec[2], vec[3])
    #    j2000 = measure(frame, itrf, dir"J2000")
    #    image = extract_image(map, itrf)

    #    @show region
    #    @show j2000

    #    figure(1); clf()
    #    imshow(image, interpolation="nearest")
    #    gca()[:set_aspect]("equal")
    #    colorbar()

    #    print("Continue? ")
    #    inp = chomp(readline())
    #    inp == "q" && break
    #end

    output = HealpixMap(Float64, 512)
    for idx = 1:length(regions)
        for pixel in regions[idx]
            output[pixel] = idx
        end
    end
    writehealpix(joinpath(dir, "tmp", "sources.fits"), output, replace=true)

    regions
end

function select_pixels(map, cutoff)
    N = length(map)
    ok = ones(Bool, N)
    rhat = zeros(3, N)
    for pixel = 1:N
        rhat[:, pixel] = LibHealpix.pix2vec_ring(nside(map), pixel)
    end

    meta = getmeta(18, "rainy")
    frame = TTCal.reference_frame(meta)

    # Cut pixels that are too low in declination
    dec_limit = -30
    north = [0, 0, 1]
    for pixel = 1:N
        dec = 90 - acosd(dot(north, rhat[:, pixel]))
        if dec < dec_limit
            ok[pixel] = false
        end
    end

    # Cut pixels that are too close to the galactic plane
    north_gal_limit = 10
    south_gal_limit = -10
    direction = measure(frame, Direction(dir"GALACTIC", 0degrees, 90degrees), dir"ITRF")
    galactic_north = [direction.x, direction.y, direction.z]
    for pixel = 1:N
        lat = 90 - acosd(dot(galactic_north, rhat[:, pixel]))
        if south_gal_limit < lat < north_gal_limit
            ok[pixel] = false
        end
    end

    # Cut pixels that are too close to the Sun
    sun_limit = 1
    direction = measure(frame, Direction(dir"SUN"), dir"ITRF")
    sun = [direction.x, direction.y, direction.z]
    for pixel = 1:N
        dist = acosd(dot(sun, rhat[:, pixel]))
        if dist < sun_limit
            ok[pixel] = false
        end
    end

    # Finally choose our pixels!
    output = Int[]
    for pixel = 1:N
        if ok[pixel] && map[pixel] > cutoff
            push!(output, pixel)
        end
    end
    output
end

function select_regions(map, cutoff)
    selection = select_pixels(map, cutoff)
    neighbors = LibHealpix.neighbors(map, selection)

    # Merge the pixels into sets if they are neighbors of each other.
    sets = Set[]
    for (pixel, nearby_pixels) in zip(selection, neighbors)
        found_a_set = false
        for nearby_pixel in nearby_pixels
            for set in sets
                if nearby_pixel in set
                    push!(set, pixel)
                    found_a_set = true
                end
            end
        end
        if !found_a_set
            push!(sets, Set(pixel))
        end
    end

    # Merge the sets if their intersection is not empty. This step is necessary because in the
    # previous step we made sure each pixel gets added to all the sets that border it, but don't
    # merge those sets even though they are now contiguous.
    done = false
    while !done
        done = true
        for idx = 1:length(sets), jdx = idx+1:length(sets)
            si = sets[idx]
            sj = sets[jdx]
            intersection = intersect(si, sj)
            if !isempty(intersection)
                deleteat!(sets, (idx, jdx))
                push!(sets, union(si, sj))
                done = false
                break
            end
        end
    end
    sets
end

