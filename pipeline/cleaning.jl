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
end

function clean(spw, dataset="rainy")
    dir = getdir(spw)
    @time map = readhealpix(joinpath(dir, "map-rfi-subtracted-peeled-$dataset-itrf.fits"))
    @time alm = load(joinpath(dir, "alm-rfi-subtracted-peeled-$dataset.jld"), "alm")
    @time regions = find_sources_in_the_map(spw, "map-rfi-subtracted-peeled-$dataset-itrf")
    @time cleaning_regions = construct_cleaning_regions(map, regions)
    map = _clean(spw, dataset, map, lmax(alm), mmax(alm), cleaning_regions)
    writehealpix(joinpath(dir, "tmp", "cleaned.fits"), map, replace=true)
    map
end

function _clean(spw, dataset, map, lmax, mmax, cleaning_regions)
    println("===")
    @time @sync for worker in workers()
        @async begin
            remotecall_fetch(CleanWorker.read_observation_matrix, worker, spw, dataset)
            remotecall_fetch(CleanWorker.set_lmax_mmax, worker, lmax, mmax)
        end
    end

    N = length(cleaning_regions)
    completed = fill(false, N)
    for iteration = 1:10
        @show iteration
        incomplete_regions = @view cleaning_regions[!completed]
        completed_view = @view completed[!completed]
        indices = pick_regions(map, incomplete_regions, 100)

        function nextidx()
            if length(indices) == 0
                return 0
            else
                return pop!(indices)
            end
        end

        prg = Progress(length(indices), "Progress: ")
        lck = ReentrantLock()
        increment_progress() = (lock(lck); next!(prg); unlock(lck))

        list_of_indices = Vector{Int}(length(indices))
        list_of_fluxes = Vector{Float64}(length(indices))
        list_of_centroids = Vector{Direction}(length(indices))
        list_of_psfs = Vector{HealpixMap}(length(indices))
        function update_lists(idx, flux, centroid, psf)
            list_of_indices[idx] = idx
            list_of_fluxes[idx] = flux
            list_of_centroids[idx] = centroid
            list_of_psfs[idx] = psf
        end

        @time @sync for worker in workers()
            @async remotecall_fetch(CleanWorker.set_map, worker, map)
        end

        @time @sync for worker in workers()
            @async while true
                idx = nextidx()
                idx == 0 && break
                region = cleaning_regions[idx]
                flux, centroid, psf = remotecall_fetch(CleanWorker.clean_major_iteration, worker, region)
                update_lists(idx, flux, centroid, psf)
                increment_progress()
            end
        end

        λ = 0.5
        for (idx, flux, centroid, psf) in zip(list_of_indices, list_of_fluxes,
                                              list_of_centroids, list_of_psfs)
            map -= λ*psf
            if abs(flux) < 0.1
                completed_view[idx] = true
            end
        end
    end
    map
end

function pick_regions(map, cleaning_regions, N)
    N = min(N, length(cleaning_regions))
    residuals = zeros(length(cleaning_regions))
    for (idx, region) in enumerate(cleaning_regions)
        background = CleanWorker.get_region_median(map, region.annulus)
        residuals[idx] = maximum(map[pixel] for pixel in region.aperture)
    end
    perm = sortperm(residuals, rev=true)
    perm[1:N]
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
        center = CleanWorker.get_region_centroid(map, region)
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

