module Cleaning

using JLD
using ProgressMeter
using CasaCore.Measures
using LibHealpix
using TTCal
using BPJSpec
using NLopt
using ..Common

include("fix-flux-scale.jl")
include("register.jl")

include("getpsf.jl")
#include("clean-worker.jl")
include("clean.jl")
include("postage-stamp.jl")

#include("clean-worker.jl")

#function clean(spw, dataset="rainy")
#    dir = getdir(spw)
#    map = readhealpix(joinpath(dir, "map-rfi-subtracted-peeled-$dataset-itrf.fits"))
#    alm = load(joinpath(dir, "alm-rfi-subtracted-peeled-$dataset.jld"), "alm")
#    regions = find_sources_in_the_map(spw, dataset)
#    @show length(regions)
#    cleaning_regions = construct_cleaning_regions(map, regions)
#    @show length(cleaning_regions)
#    cleaning_regions = discard_nearby_cleaning_regions(map, cleaning_regions)
#    @show length(cleaning_regions)
#
#
#    #meta = getmeta(spw, dataset)
#    #frame = TTCal.reference_frame(meta)
#    #for region in cleaning_regions
#    #    j2000 = measure(frame, region.center, dir"J2000")
#    #    image = GetPSF.extract_image(map, region.center)
#
#    #    @show j2000
#
#    #    figure(1); clf()
#    #    imshow(image, interpolation="nearest")
#    #    gca()[:set_aspect]("equal")
#    #    grid("on")
#    #    colorbar()
#
#    #    print("Continue? ")
#    #    inp = chomp(readline())
#    #    inp == "q" && break
#    #end
#
#
#
#
#
#    map = _clean(spw, dataset, map, lmax(alm), mmax(alm), cleaning_regions)
#    writehealpix(joinpath(dir, "tmp", "cleaned.fits"), map, replace=true)
#    map
#end
#
#function _clean(spw, dataset, map, lmax, mmax, cleaning_regions)
#    println("===")
#    @time @sync for worker in workers()
#        @async begin
#            remotecall_fetch(CleanWorker.read_observation_matrix, worker, spw, dataset)
#            remotecall_fetch(CleanWorker.set_lmax_mmax, worker, lmax, mmax)
#        end
#    end
#
#    N = length(cleaning_regions)
#    completed = fill(false, N)
#    for iteration = 1:10
#        @show iteration
#        incomplete_regions = @view cleaning_regions[!completed]
#        completed_view = @view completed[!completed]
#        indices = pick_regions(map, incomplete_regions, 100)
#
#        function nextidx()
#            if length(indices) == 0
#                return 0
#            else
#                return pop!(indices)
#            end
#        end
#
#        prg = Progress(length(indices), "Progress: ")
#        lck = ReentrantLock()
#        increment_progress() = (lock(lck); next!(prg); unlock(lck))
#
#        list_of_indices = Int[]
#        list_of_fluxes = Float64[]
#        list_of_centroids = Direction[]
#        list_of_psfs = HealpixMap[]
#        function update_lists(idx, flux, centroid, psf)
#            push!(list_of_indices, idx)
#            push!(list_of_fluxes, flux)
#            push!(list_of_centroids, centroid)
#            push!(list_of_psfs, psf)
#        end
#
#        @time @sync for worker in workers()
#            @async remotecall_fetch(CleanWorker.set_map, worker, map)
#        end
#
#        @time @sync for worker in workers()
#            @async while true
#                idx = nextidx()
#                idx == 0 && break
#                region = cleaning_regions[idx]
#                flux, centroid, psf = remotecall_fetch(CleanWorker.clean_major_iteration, worker, region)
#                update_lists(idx, flux, centroid, psf)
#                increment_progress()
#            end
#        end
#
#        λ = 0.15
#        for (idx, flux, centroid, psf) in zip(list_of_indices, list_of_fluxes,
#                                              list_of_centroids, list_of_psfs)
#            map -= λ*psf
#            if abs(flux) < 0.1
#                completed_view[idx] = true
#            end
#        end
#    end
#    map
#end
#
#immutable CleaningRegion
#    center :: Direction
#    aperture :: Set{Int}
#    annulus  :: Set{Int}
#end
#
#function construct_cleaning_regions(map, regions)
#    N = length(map)
#    rhat = zeros(3, N)
#    for pixel = 1:N
#        rhat[:, pixel] = LibHealpix.pix2vec_ring(nside(map), pixel)
#    end
#
#    output = CleaningRegion[]
#    for region in regions
#        center = CleanWorker.get_region_centroid(map, region)
#        aperture = Set{Int}()
#        annulus  = Set{Int}()
#        for pixel = 1:N
#            dotproduct = (rhat[1, pixel]*center.x
#                          + rhat[2, pixel]*center.y
#                          + rhat[3, pixel]*center.z)
#            # I'm seeing cases where the dot product is slightly out of the domain of arccos.
#            # Eg. +1.0000000000000002, -1.0000000000000002
#            dotproduct = min(dotproduct, +1.0)
#            dotproduct = max(dotproduct, -1.0)
#            θ = acosd(dotproduct)
#            if θ < 0.25
#                push!(aperture, pixel)
#            elseif 3 < θ < 5
#                push!(annulus, pixel)
#            end
#        end
#        push!(output, CleaningRegion(center, aperture, annulus))
#    end
#    output
#end
#
#function discard_nearby_cleaning_regions(map, regions)
#    # If two regions are too close to each other, we should discard the fainter one. This will
#    # prevent us from erroneously picking out sidelobes before we have had an opportunity to
#    # deconvolve them.
#    done = false
#    while !done
#        done = true
#        for idx = 1:length(regions), jdx = idx+1:length(regions)
#            r1 = regions[idx]
#            r2 = regions[jdx]
#            a = r1.center
#            b = r2.center
#            θ = acosd(a.x*b.x + a.y*b.y + a.z*b.z)
#            if θ < 2
#                @show a b
#                background1 = CleanWorker.get_region_median(map, r1.annulus)
#                background2 = CleanWorker.get_region_median(map, r2.annulus)
#                amplitude1 = maximum(map[pixel] - background1 for pixel in r1.aperture)
#                amplitude2 = maximum(map[pixel] - background2 for pixel in r2.aperture)
#                if amplitude1 ≥ amplitude2
#                    deleteat!(regions, jdx)
#                else
#                    deleteat!(regions, idx)
#                end
#                done = false
#                break
#            end
#        end
#    end
#    regions
#end
#
#function pick_regions(map, cleaning_regions, N)
#    N = min(N, length(cleaning_regions))
#    residuals = zeros(length(cleaning_regions))
#    for (idx, region) in enumerate(cleaning_regions)
#        background = CleanWorker.get_region_median(map, region.annulus)
#        residuals[idx] = maximum(map[pixel]-background for pixel in region.aperture)
#    end
#    perm = sortperm(residuals, rev=true)
#    perm[1:N]
#end

end

