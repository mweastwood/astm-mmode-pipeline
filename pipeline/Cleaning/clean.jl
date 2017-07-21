function clean(dataset)
    println("Cleaning")
    spws = 4:2:18
    pool = classify_workers(spws)
    io = start_workers(pool, spws, dataset)
    try
        psfs = loadpsf_peak(spws, dataset)
        maps = readmaps(spws, dataset)
        x, y, z = unit_vectors(nside(maps[1]))
        clean(spws, dataset, pool, io, psfs, maps, x, y, z)
    finally
        close_worker_io(io)
    end
end

function clean(spws, dataset, pool, io, psfs, maps, x, y, z)
    maxiter = 500
    for iter = 1:maxiter
        println("================")
        @printf("Iteration #%05d\n", iter)
        @time maps = clean_iteration(pool, io, psfs, maps, x, y, z)
        if mod(iter, 50) == 0
            println("...writing maps...")
            for (spw, map) in zip(spws, maps)
                dir = getdir(spw)
                iterstr = @sprintf("%05d", iter)
                filename = "cleaned-map-$dataset-$iterstr.fits"
                writehealpix(joinpath(dir, "tmp", filename), map, replace=true)
            end
        end
    end
end

function clean_iteration(pool, io, psfs, maps, x, y, z)
    Npixels = 256
    println("* selecting pixels")
    @time pixels = select_pixels(maps, x, y, z, Npixels)
    println("* spherical harmonics")
    @time model_alms = spherical_harmonics(pool, maps, psfs, pixels)
    println("* observing")
    @time model_alms = observe(pool, io, model_alms)
    println("* spherical harmonic transforms")
    @time model_maps = spherical_harmonic_transforms(pool, model_alms, nside(maps[1]))
    println("* subtracting model")
    @time subtract_model(maps, model_maps, 0.25)
end

function spherical_harmonics(pool, maps, psfs, pixels)
    N = length(maps)
    lmax = mmax = 1000
    alms = Alm[Alm(Complex128, lmax, mmax) for map in maps]
    function output(myalm, θ, ϕ, pixel)
        for idx = 1:N
            scale = maps[idx][pixel] / getpeak(psfs[idx], θ)
            alms[idx].alm[:] += scale * myalm.alm
        end
    end
    not_done() = length(pixels) > 0
    next_pixel() = pop!(pixels)
    angles(pixel) = LibHealpix.pix2ang_ring(nside(maps[1]), pixel)
    workers = [pool.spherical_harmonic_workers; pool.spherical_harmonic_transform_workers]
    @sync for worker in workers
        @async while not_done()
            mypixel = next_pixel()
            θ, ϕ = angles(mypixel)
            myalm = remotecall_fetch(pointsource_alm, worker, θ, ϕ, lmax, mmax)
            output(myalm, θ, ϕ, mypixel)
        end
    end
    alms
end

function observe(pool, io, alms)
    N = length(alms)
    for idx = 1:N
        channel = io.observation_matrix_worker_input[idx]
        put!(channel, alms[idx])
    end
    Alm[take!(channel) for channel in io.observation_matrix_worker_output]
end

function spherical_harmonic_transforms(pool, alms, nside)
    sht(alm) = alm2map(alm, nside)
    workers = pool.spherical_harmonic_transform_workers
    futures = [remotecall(sht, worker, alm) for (worker, alm) in zip(workers, alms)]
    HealpixMap[fetch(future) for future in futures]
end

function subtract_model(maps, models, λ)
    [map - λ*model for (map, model) in zip(maps, models)]
end

function select_pixels(maps, x, y, z, N)
    T = eltype(maps[1].pixels)
    map = sum(maps)
    abs_pixel_values = abs(map.pixels)::Vector{T}
    sorted_pixels = sortperm(abs_pixel_values)::Vector{Int}
    selected_pixels = Int[]
    while length(selected_pixels) < N
        @label top
        # take the pixel with the largest absolute value
        pixel = pop!(sorted_pixels)
        # verify we're not too close to other already selected pixels
        for selected_pixel in selected_pixels
            dotproduct = (x[pixel]*x[selected_pixel] + y[pixel]*y[selected_pixel]
                          + z[pixel]*z[selected_pixel])
            # in rare cases it seems like this dot product can fall just outside of the domain
            # of acos due to floating point precision, so we will clamp the result to ensure
            # that we don't get a DomainError
            distance = acosd(clamp(dotproduct, -1, 1))
            distance < 3 && @goto top
        end
        push!(selected_pixels, pixel)
    end
    selected_pixels
end

function readmap(spw, dataset, target)
    dir = getdir(spw)
    readhealpix(joinpath(dir, "$target-$dataset-itrf.fits"))
end

readmaps(spws, dataset, target) = HealpixMap[readmap(spw, dataset, target) for spw in spws]

function unit_vectors(nside)
    npix = nside2npix(nside)
    x = zeros(npix)
    y = zeros(npix)
    z = zeros(npix)
    for pix = 1:npix
        vec = LibHealpix.pix2vec_ring(nside, pix)
        x[pix] = vec[1]
        y[pix] = vec[2]
        z[pix] = vec[3]
    end
    x, y, z
end

