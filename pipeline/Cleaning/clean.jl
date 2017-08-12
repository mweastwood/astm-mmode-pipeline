function clean(spw, dataset, target)
    output_directory = joinpath(getdir(spw), "cleaning")
    isdir(output_directory) || mkdir(output_directory)

    psf = load(joinpath(getdir(spw), "psf", "psf.jld"), "psf")
    residual_alm, mrange =
        load(joinpath(getdir(spw), "$target-$dataset.jld"), "alm", "mrange")
    observation_matrix_path = joinpath(getdir(spw), "observation-matrix-$dataset.jld")
    observation_matrix, cholesky_decomposition =
        load(observation_matrix_path, "blocks", "cholesky")
    workload = distribute_workload(observation_matrix, cholesky_decomposition)

    nside = 2048
    x, y, z = unit_vectors(nside)
    clean_mask = create_mask(spw, dataset, x, y, z)
    clean_components = HealpixMap(Float64, nside)

    maxiter = 2048
    Npixels = 256

    clean(spw, dataset, target, psf, residual_alm,
          workload, clean_mask, clean_components, x, y, z,
          maxiter, mrange, Npixels, output_directory)
end

function clean(spw, dataset, target, psf, residual_alm,
               workload, clean_mask, clean_components, x, y, z,
               maxiter, mrange, Npixels, output_directory)

    residual_map = alm2map(residual_alm, nside(clean_components))
    for iter = 1:maxiter
        println("================")
        @printf("Iteration #%05d\n", iter)
        println("time = ", now())
        println("stddev = ", std(residual_map.pixels[clean_mask]))

        @time residual_map = clean_iteration!(psf, residual_alm, residual_map,
                                              workload, clean_mask, clean_components,
                                              x, y, z, mrange, Npixels)

        if mod(iter, 128) == 0
            println("...writing maps...")
            dir = getdir(spw)
            iterstr = @sprintf("%05d", iter)
            filename = "residual-map-$iterstr.fits"
            writehealpix(joinpath(output_directory, filename), residual_map, replace=true)
            filename = "clean-components-$iterstr.fits"
            writehealpix(joinpath(output_directory, filename), clean_components, replace=true)
        end
    end

    save(joinpath(output_directory, "final.jld"),
         "residual_alm", residual_alm.alm,
         "residual_map", residual_map.pixels,
         "clean_components", clean_components.pixels)
end

function clean_iteration!(psf, residual_alm, residual_map,
                          workload, clean_mask, clean_components,
                          x, y, z, mrange, Npixels)

    println("* selecting pixels")
    @time pixels = select_pixels(residual_map, clean_mask, x, y, z, Npixels)

    println("* computing spherical harmonics")
    @time model_alm = compute_spherical_harmonics!(residual_alm, residual_map,
                                                   clean_components, psf, pixels)

    println("* corrupting spherical harmonics")
    @time corrupt_spherical_harmonics!(model_alm, workload, mrange)

    println("* removing clean components")
    @time residual_alm.alm[:] -= model_alm.alm

    println("* creating new residual map")
    @time residual_map = alm2map(residual_alm, nside(residual_map))

    residual_map
end

function create_mask(spw, dataset, x, y, z)
    N = length(x)
    mask = Int[]
    meta = getmeta(spw, dataset)
    frame = TTCal.reference_frame(meta)
    #_per_a = measure(frame, Direction(dir"J2000", "03h19m48.16010s", "+41d30m42.1031s"), dir"ITRF")
    #_3c134 = measure(frame, Direction(dir"J2000", "05h04m42.0s", "+38d06m02s"), dir"ITRF")
    for pixel = 1:N
        declination = acosd(z[pixel])
        #dotproduct = x[pixel]*_3c134.x + y[pixel]*_3c134.y + z[pixel]*_3c134.z
        #distance = acosd(clamp(dotproduct, -1, 1))
        if declination > -30 #&& distance < 0.5
            push!(mask, pixel)
        end
    end
    mask
end

function select_pixels(residual_map, clean_mask, x, y, z, Npixels)
    sorted_pixels = clean_mask[sortperm(residual_map.pixels[clean_mask])]
    selected_pixels = Int[]
    while length(selected_pixels) < Npixels
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
    sort(selected_pixels)
end

function compute_spherical_harmonics!(residual_alm, residual_map,
                                      clean_components, psf, pixels)
    L = lmax(residual_alm)
    M = mmax(residual_alm)
    N = nside(residual_map)

    model_alm = Alm(Complex128, L, M)
    function add_component(component_alm, pixel)
        ring = searchsortedlast(psf.pixels, pixel)
        scale = 0.15*residual_map[pixel]/psf.amplitudes[ring]
        clean_components[pixel] += scale
        model_alm.alm[:] += scale*component_alm.alm
    end

    next_pixel() = pop!(pixels)
    done() = length(pixels) == 0
    @sync for worker in workers()
        @async while !done()
            pixel′ = next_pixel()
            θ, ϕ = LibHealpix.pix2ang_ring(N, pixel′)
            component_alm = remotecall_fetch(pointsource_alm, worker, θ, ϕ, L, M)
            add_component(component_alm, pixel′)
        end
    end

    model_alm
end

module CleanWorker
    const M = Matrix{Complex128}
    const U = UpperTriangular{Complex128, M}
    const observation_matrix_blocks = Dict{Int, M}()
    const cholesky_decomposition_blocks = Dict{Int, U}()
end

function transfer_blocks(m, observation_matrix_block, cholesky_decomposition_block)
    CleanWorker.observation_matrix_blocks[m] = observation_matrix_block
    CleanWorker.cholesky_decomposition_blocks[m] = cholesky_decomposition_block
end

function distribute_workload(observation_matrix, cholesky_decomposition)
    mmax = length(observation_matrix)-1
    workload = Dict{Int, Int}()
    @sync for (worker, m) in zip(cycle(workers()), 0:mmax)
        workload[m] = worker
        @async remotecall_wait(transfer_blocks, worker, m,
                               observation_matrix[m+1],
                               cholesky_decomposition[m+1])
    end
    empty!(observation_matrix)
    empty!(cholesky_decomposition)
    workload
end

function corrupt_spherical_harmonics!(model_alm, workload, mrange)
    function output(corrupted_alm, m)
        for l = m:lmax(model_alm)
            model_alm[l, m] = corrupted_alm[l-m+1]
        end
    end
    @sync for m = 0:mmax(model_alm)
        @async begin
            worker = workload[m]
            input_alm = [model_alm[l, m] for l = m:lmax(model_alm)]
            corrupted_alm = remotecall_fetch(corrupt_spherical_harmonics_block,
                                             worker, input_alm, m)
            output(corrupted_alm, m)
        end
    end
    MModes.apply_wiener_filter!(model_alm, mrange)
end

function corrupt_spherical_harmonics_block(input_alm, m)
    observe_block(CleanWorker.observation_matrix_blocks[m],
                  CleanWorker.cholesky_decomposition_blocks[m],
                  input_alm)
end

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

function rotate_alm!(alm, dϕ)
    for m = 0:mmax(alm)
        cismdϕ = cis(-m*dϕ)
        for l = m:lmax(alm)
            alm[l, m] *= cismdϕ
        end
    end
end

