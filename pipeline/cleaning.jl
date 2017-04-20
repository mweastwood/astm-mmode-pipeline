function clean(spw, dataset="rainy")
    dir = getdir(spw)
    map = readhealpix(joinpath(dir, "map-rfi-subtracted-peeled-$dataset-itrf.fits"))
    alm = load(joinpath(dir, "alm-rfi-subtracted-peeled-$dataset.jld"), "alm")
    observation = load(joinpath(dir, "observation-matrix-$dataset.jld"), "blocks")
    regions = find_sources_in_the_map(spw, "map-rfi-subtracted-peeled-$dataset-itrf")
    cleaning_regions = construct_cleaning_regions(map, regions)
    map, alm = _clean(map, alm, observation, cleaning_regions)
    writehealpix(joinpath(dir, "tmp", "cleaned.fits"), map, replace=true)
    map, alm
end

function _clean(map, alm, observation, cleaning_regions)
    N = length(cleaning_regions)
    done = fill(false, N)
    for iteration = 1:10N
        idx, residual, region = pick_region(map, cleaning_regions[!done])
        @show region.center, residual
        @time map, alm, flux = clean_do_a_major_iteration(map, alm, observation, region)
        @show flux

        # Stop cleaning a region when the measured flux drops below 0.1 Jy
        if abs(flux) < 0.1
            @view(done[!done])[idx] = true
        end
        @show sum(done)
    end
    map, alm
end

function pick_region(map, cleaning_regions)
    residuals = zeros(length(cleaning_regions))
    for (idx, region) in enumerate(cleaning_regions)
        background = get_region_median(map, region.annulus)
        residuals[idx] = maximum(map[pixel] for pixel in region.aperture)
    end
    jdx = indmax(residuals)
    jdx, residuals[jdx], cleaning_regions[jdx]
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
    psf_alm  = getpsf_alm(observation, π/2-latitude(centroid), longitude(centroid),
                          lmax(alm), mmax(alm))
    psf  = alm2map(psf_alm, nside(map))
    flux = get_region_flux(map, psf, background, region.aperture)
    @show centroid, flux

    λ = 0.5
    map -= λ*flux*psf
    alm -= λ*flux*psf_alm
    map, alm, flux
end

