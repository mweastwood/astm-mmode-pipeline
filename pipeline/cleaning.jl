function clean(spw, target)
    dir = getdir(spw)
    map = readhealpix(joinpath(dir, target*".fits"))
    regions = find_sources_in_the_map(spw, target)
    psf_dec, psf = load_psf(spw)
    cleaning_regions = construct_cleaning_regions(map, regions)

    for region in cleaning_regions
        clean_do_a_minor_iteration(map, psf_dec, psf, region)
        print("Continue? ")
        inp = chomp(readline())
        inp == "q" && break
    end
end

immutable CleaningRegion
    centroid :: Direction
    pixels :: Set{Int}
end

function construct_cleaning_regions(map, regions)
    output = CleaningRegion[]
    for region in regions
        centroid = get_region_centroid(map, region)
        push!(output, CleaningRegion(centroid, region))
    end
    output
end

function get_region_centroid(map, region) :: Direction
    normalization = 0.0
    centroid = [0.0, 0.0, 0.0]
    for pixel in region
        normalization += map[pixel]
        centroid += map[pixel]*LibHealpix.pix2vec_ring(nside(map), pixel)
    end
    centroid /= normalization
    centroid /= norm(centroid)
    Direction(dir"ITRF", centroid[1], centroid[2], centroid[3])
end

function find_the_brightest_region(map, cleaning_regions)
    idx = indmax(maximum(map[pixel] for pixel in region.pixels) for region in cleaning_regions)
    cleaning_regions[idx]
end

function clean_do_a_minor_iteration(map, psf_dec, psf, region)
    image = extract_image(map, region.centroid)
    mypsf = interpolate_psf(psf_dec, psf, latitude(region.centroid))
    mypsf_interp = interpolate(mypsf, BSpline(Quadratic(Flat())), OnGrid())

    function fitted_psf(x, range)
        xrange = (range[1]+x[2]):(range[end]+x[2])
        yrange = (range[1]+x[3]):(range[end]+x[3])
        x[1]*mypsf_interp[xrange, yrange]
    end

    function residual_image(x, range)
        cut_mypsf = fitted_psf(x, range)
        cut_image = image[range, range]
        cut_image - cut_mypsf - x[4]
    end

    function residual(x, g)
        vecnorm(residual_image(x, 76:126))
    end

    function subtract(x, scale=0.15)
        image[2:199, 2:199] -= scale*fitted_psf(x, 2:199)
    end

    @show region

    figure(1); clf()
    imshow(image, interpolation="nearest")
    gca()[:set_aspect]("equal")
    colorbar()
    grid("on")

    figure(2); clf()
    imshow(mypsf, interpolation="nearest")
    gca()[:set_aspect]("equal")
    colorbar()
    grid("on")

    x0   = [+1e1,  0,  0,  1e6]
    xmin = [-1e5, -1, -1, -1e7]
    xmax = [+1e5, +1, +1, +1e7]

    for iter = 1:100
        opt = Opt(:LN_COBYLA, length(x0))
        ftol_rel!(opt, 1e-3)
        min_objective!(opt, residual)
        lower_bounds!(opt, xmin)
        upper_bounds!(opt, xmax)
        minf, x, ret = optimize(opt, x0)
        @show minf, x, ret
        subtract(x, 0.15)
    end

    figure(3); clf()
    imshow(image, interpolation="nearest")
    gca()[:set_aspect]("equal")
    colorbar()
    grid("on")
end

