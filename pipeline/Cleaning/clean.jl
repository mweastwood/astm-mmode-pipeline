function clean(spw, dataset, target="map-wiener-filtered")
    println("Cleaning")
    dir = getdir(spw)
    matrix = load(joinpath(dir, "observation-matrix-$dataset.jld"), "blocks")
    psf = loadpsf_peak(spw, dataset)
    map = readhealpix(joinpath(dir, "$target-$dataset-2048-itrf.fits"))
    tolerance = load(joinpath(dir, "$(replace(target, "map", "alm"))-$dataset.jld"), "tolerance")
    cholesky = cholesky_decomposition(matrix, tolerance)
    x, y, z = unit_vectors(nside(map))
    mask = create_mask(spw, dataset, x, y, z)
    clean(spw, dataset, target, matrix, cholesky, psf, map, mask, x, y, z)
end

function clean(spw, dataset, target, matrix, cholesky, psf, map, mask, x, y, z)
    #maxiter = 1024
    maxiter = 50
    components = HealpixMap(Float64, nside(map))
    for iter = 1:maxiter
        println("================")
        @printf("Iteration #%05d\n", iter)
        @time map, components = clean_iteration(matrix, cholesky, psf, map, components, mask, x, y, z)
        #if mod(iter, 128) == 0
        if mod(iter, 1) == 0
            println("...writing maps...")
            dir = getdir(spw)
            iterstr = @sprintf("%05d", iter)
            #filename = "cleaned-$target-$dataset-$iterstr.fits"
            filename = "test-cleaned-$target-$dataset-$iterstr.fits"
            #writehealpix(joinpath(dir, "tmp", filename), map, replace=true)
            writehealpix(joinpath(dir, "tmp", filename), alm2map(map2alm(map, 1000, 1000), 512), replace=true)
            ##filename = "clean-components-$target-$dataset-$iterstr.fits"
            #filename = "test-clean-components-$target-$dataset-$iterstr.fits"
            #writehealpix(joinpath(dir, "tmp", filename), components, replace=true)
        end
    end
end

function clean_iteration(matrix, cholesky, psf, map, components, mask, x, y, z)
    #Npixels = 256
    Npixels = 1
    println("* selecting pixels")
    @time pixels = select_pixels(map, mask, x, y, z, Npixels)
    println("* spherical harmonics")
    @time model_alm = spherical_harmonics(map, components, psf, pixels)
    println("* observing")
    @time model_alm = observe(matrix, cholesky, model_alm)
    println("* spherical harmonic transform")
    @time model_map = alm2map(model_alm, nside(map))
    println("* subtracting model")
    @time map = map - 0.15*model_map
    map, components
end

function cholesky_decomposition(matrix, tolerance)
    [chol(block + tolerance*I) for block in matrix]
end

function create_mask(spw, dataset, x, y, z)
    N = length(x)
    mask = Int[]
    meta = getmeta(spw, dataset)
    frame = TTCal.reference_frame(meta)
    #per_a = measure(frame, Direction(dir"J2000", "03h19m48.16010s", "+41d30m42.1031s"), dir"ITRF")
    _3c_134 = measure(frame, Direction(dir"J2000", "05h04m42.0s", "+38d06m02s"), dir"ITRF")
    for pixel = 1:N
        #dotproduct = x[pixel]*per_a.x + y[pixel]*per_a.y + z[pixel]*per_a.z
        dotproduct = x[pixel]*_3c_134.x + y[pixel]*_3c_134.y + z[pixel]*_3c_134.z
        distance = acosd(clamp(dotproduct, -1, 1))
        if distance < 0.2
            push!(mask, pixel)
        end
    end
    @show length(mask)
    mask
end

function select_pixels(map, mask, x, y, z, N)
    #sorted_pixels = sortperm(abs(map.pixels))
    #sorted_pixels = sortperm(map.pixels)
    sorted_pixels = mask[sortperm(map.pixels[mask])]
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

function spherical_harmonics(map, components, psf, pixels)
    lmax = mmax = 1000
    alm  = Alm(Complex128, lmax, mmax)
    function output(myalm, θ, ϕ, pixel)
        scale = map[pixel] / getpeak(psf, θ)
        components[pixel] += scale
        alm.alm[:] += scale * myalm.alm
    end
    not_done() = length(pixels) > 0
    next_pixel() = pop!(pixels)
    angles(pixel) = LibHealpix.pix2ang_ring(nside(map), pixel)
    @sync for worker in workers()
        @async while not_done()
            mypixel = next_pixel()
            θ, ϕ = angles(mypixel)
            myalm = remotecall_fetch(pointsource_alm, worker, θ, ϕ, lmax, mmax)
            output(myalm, θ, ϕ, mypixel)
        end
    end
    alm
end

function observe(observation_matrix, cholesky, input_alm)
    output_alm = Alm(Complex128, lmax(input_alm), mmax(input_alm))
    for m = 0:mmax(input_alm)
        #A = observation_matrix[m+1]
        BB = observation_matrix[m+1]
        U  = cholesky[m+1]
        L  = U'

        x = [input_alm[l, m] for l = m:lmax(input_alm)]
        #y = A*x
        y = U\(L\(BB*x))
        for l = m:lmax(input_alm)
            output_alm[l, m] = y[l-m+1]
        end
    end
    output_alm
end

#function spherical_harmonic_transforms(pool, alms, nside)
#    sht(alm) = alm2map(alm, nside)
#    workers = pool.spherical_harmonic_transform_workers
#    futures = [remotecall(sht, worker, alm) for (worker, alm) in zip(workers, alms)]
#    HealpixMap[fetch(future) for future in futures]
#end
#
#function subtract_model(maps, models, λ)
#    [map - λ*model for (map, model) in zip(maps, models)]
#end
#
#function readmap(spw, dataset, target)
#    dir = getdir(spw)
#    readhealpix(joinpath(dir, "$target-$dataset-2048-itrf.fits"))
#end
#
#readmaps(spws, dataset, target) = HealpixMap[readmap(spw, dataset, target) for spw in spws]

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

