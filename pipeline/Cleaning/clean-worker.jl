module CleanWorker
    using CasaCore.Measures
    using JLD
    using LibHealpix

    using ..Common
    import ..GetPSF

    function set_map(_map)
        global map = _map
        nothing
    end

    function set_lmax_mmax(_lmax, _mmax)
        global lmax = _lmax
        global mmax = _mmax
        nothing
    end

    function read_observation_matrix(spw, dataset)
        global observation = load(joinpath(getdir(18), "observation-matrix-$dataset.jld"), "blocks")
        nothing
    end

    function clean_major_iteration(region)
        clean_major_iteration(map, observation, lmax, mmax, region)
    end

    function clean_major_iteration(map, observation, lmax, mmax, region)
        background = get_region_median(map, region.annulus)
        centroid = get_region_centroid(map, region.aperture, background)
        psf_alm  = GetPSF.getpsf_alm(observation, π/2-latitude(centroid), longitude(centroid), lmax, mmax)
        psf  = alm2map(psf_alm, nside(map))
        flux = get_region_flux(map, psf, background, region.aperture)
        flux, centroid, flux*psf
    end

    function get_region_centroid(map, region, background) :: Direction
        #normalization = 0.0
        #centroid = [0.0, 0.0, 0.0]
        #for pixel in region
        #    difference = map[pixel] - background
        #    if difference ≥ 0
        #        # Taking a centroid doesn't seem to make sense when talking about negative pixels. We'll
        #        # just exclude those pixels for now, but it seems like we should do something a little
        #        # more intelligent.
        #        normalization += difference
        #        centroid += difference*LibHealpix.pix2vec_ring(nside(map), pixel)
        #    end
        #end
        #centroid /= normalization
        #centroid /= norm(centroid)
        max_residual = 0.0
        centroid = [0.0, 0.0, 0.0]
        for pixel in region
            residual = abs(map[pixel] - background)
            if residual > max_residual
                max_residual = residual
                centroid = LibHealpix.pix2vec_ring(nside(map), pixel)
            end
        end
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
end

