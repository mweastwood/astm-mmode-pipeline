function clean(spw, dataset)
    dir = getdir(spw)

    println("reading observation matrix")
    observation_matrix, lmax, mmax = load(joinpath(dir, "observation-matrix-$dataset.jld"),
                                          "blocks", "lmax", "mmax")

    println("reading PSF peak values")
    θpeaks, peaks = load(joinpath(dir, "psf-peak-value-rainy.jld"), "theta", "peaks")

    println("reading dirty map")
    map = readhealpix(joinpath(dir, "map-wiener-filtered-$dataset-itrf.fits"))

    println("computing unit vectors")
    x, y, z = unit_vectors(map)

    for idx = 1:100
        println("selecting pixels")
        @time pixels = select_pixels(map, x, y, z, 256)
        println("cleaning")
        @time model = clean(map, pixels, observation_matrix, θpeaks, peaks, lmax, mmax)
        map -= model
        writehealpix(@sprintf("test-%03d.fits", idx), map, replace=true)
    end
end

function clean(map, pixels, observation_matrix, θpeaks, peaks, lmax, mmax)
    alm = Alm(Complex128, lmax, mmax)
    # compute the contribution from each pixel
    not_done() = length(pixels) > 0
    next_pixel() = pop!(pixels)
    angles(pixel) = LibHealpix.pix2ang_ring(nside(map), pixel)
    scale(pixel, θ, ϕ) = (idx = searchsortedlast(θpeaks, θ); 0.15 * map[pixel] / peaks[idx])
    output(myalm) = alm += myalm
    @sync for worker in workers()
        @async while not_done()
            mypixel = next_pixel()
            θ, ϕ = angles(mypixel)
            myscale = scale(mypixel, θ, ϕ)
            myalm = myscale * remotecall_fetch(pointsource_alm, worker, θ, ϕ, lmax, mmax)
            output(myalm)
        end
    end
    # run these pixels through the interferometer's response
    alm = observe(observation_matrix, alm)
    alm2map(alm, nside(map))
end

function observe(observation_matrix, input_alm)
    output_alm = Alm(Complex128, lmax(input_alm), mmax(input_alm))
    for m = 0:mmax(input_alm)
        A = observation_matrix[m+1]
        x = [input_alm[l, m] for l = m:lmax(input_alm)]
        y = A*x
        for l = m:lmax(input_alm)
            output_alm[l, m] = y[l-m+1]
        end
    end
    output_alm
end

function select_pixels(map, x, y, z, N)
    abs_pixel_values = abs(map.pixels)
    @time sorted_pixels = sortperm(abs_pixel_values)
    selected_pixels = Int[]
    @time while length(selected_pixels) < N
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
            distance < 5 && @goto top
        end
        push!(selected_pixels, pixel)
    end
    selected_pixels
end

function unit_vectors(map)
    x = zeros(length(map))
    y = zeros(length(map))
    z = zeros(length(map))
    for pix = 1:length(map)
        vec = LibHealpix.pix2vec_ring(nside(map), pix)
        x[pix] = vec[1]
        y[pix] = vec[2]
        z[pix] = vec[3]
    end
    x, y, z
end

