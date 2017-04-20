function clean(spw, dataset="rainy")
    dir = getdir(spw)
    map = readhealpix(joinpath(dir, "map-rfi-subtracted-peeled-$dataset-itrf.fits"))
    alm = load(joinpath(dir, "alm-rfi-subtracted-peeled-$dataset.jld"), "alm")
    observation = load(joinpath(dir, "observation-matrix-$dataset.jld"), "blocks")
    regions = find_sources_in_the_map(spw, "map-rfi-subtracted-peeled-$dataset-itrf")
    cleaning_regions = construct_cleaning_regions(map, regions)

    for region in cleaning_regions
        @show region.center

        #figure(1); clf()
        #image = extract_image(map, region.center)
        #imshow(image, interpolation="nearest")
        #gca()[:set_aspect]("equal")
        #colorbar()
        #grid("on")

        for idx = 1:10
            @time map, alm = clean_do_a_major_iteration(map, alm, observation, region)
        end

        #figure(2); clf()
        #image = extract_image(map, region.center)
        #imshow(image, interpolation="nearest")
        #gca()[:set_aspect]("equal")
        #colorbar()
        #grid("on")

        #print("Continue? ")
        #inp = chomp(readline())
        #inp == "q" && break
    end
    map, alm
end

immutable CleaningRegion
    center :: Direction
    aperture :: Set{Int}
    annulus  :: Set{Int}
end

function construct_cleaning_regions(map, regions)
    N = length(map)
    rhat = zeros(3, N)
    for pixel = 1:N
        rhat[:, pixel] = LibHealpix.pix2vec_ring(nside(map), pixel)
    end

    output = CleaningRegion[]
    for region in regions
        center = get_region_centroid(map, region)
        aperture = Set{Int}()
        annulus  = Set{Int}()
        for pixel = 1:N
            dotproduct = (rhat[1, pixel]*center.x
                          + rhat[2, pixel]*center.y
                          + rhat[3, pixel]*center.z)
            # I'm seeing cases where the dot product is slightly out of the domain of arccos.
            # Eg. +1.0000000000000002, -1.0000000000000002
            dotproduct = min(dotproduct, +1.0)
            dotproduct = max(dotproduct, -1.0)
            θ = acosd(dotproduct)
            if θ < 0.25
                push!(aperture, pixel)
            elseif 3 < θ < 5
                push!(annulus, pixel)
            end
        end
        push!(output, CleaningRegion(center, aperture, annulus))
    end
    output
end

function get_region_centroid(map, region, background) :: Direction
    normalization = 0.0
    centroid = [0.0, 0.0, 0.0]
    for pixel in region
        difference = map[pixel] - background
        if difference ≥ 0
            # Taking a centroid doesn't seem to make sense when talking about negative pixels. We'll
            # just exclude those pixels for now, but it seems like we should do something a little
            # more intelligent.
            normalization += difference
            centroid += difference*LibHealpix.pix2vec_ring(nside(map), pixel)
        end
    end
    centroid /= normalization
    centroid /= norm(centroid)
    Direction(dir"ITRF", centroid[1], centroid[2], centroid[3])
end
get_region_centroid(map, region) = get_region_centroid(map, region, 0)

function get_region_median(map, region)
    values = [map[pixel] for pixel in region]
    median(values)
end

function get_region_flux(map, psf, background, region)
    measured = Float64[]
    model = Float64[]
    for pixel in region
        push!(measured, map[pixel])
        push!(model, psf[pixel])
    end
    scale = model\(measured-background)
    scale[1]
end

function clean_do_a_major_iteration(map, alm, observation, region)
    background = get_region_median(map, region.annulus)
    centroid = get_region_centroid(map, region.aperture, background)
    @show centroid
    psf_alm  = getpsf_alm(observation, π/2-latitude(centroid), longitude(centroid),
                          lmax(alm), mmax(alm))
    psf  = alm2map(psf_alm, nside(map))
    flux = get_region_flux(map, psf, background, region.aperture)
    @show flux

    λ = 0.5
    map -= λ*flux*psf
    alm -= λ*flux*psf_alm
    map, alm
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

