immutable FullPSF
    pixels :: Vector{Int}
    amplitudes :: Vector{Float64}
    major_σ :: Vector{Float64}
    minor_σ :: Vector{Float64}
    position_angle :: Vector{Float64}
end

immutable CleanState
    lmax :: Int
    mmax :: Int
    nside :: Int
    # unit vectors
    x :: Vector{Float64}
    y :: Vector{Float64}
    z :: Vector{Float64}
    # residuals
    residual_alm :: Alm
    residual_map :: HealpixMap
    degraded_alm :: Alm
    # clean components
    clean_components :: HealpixMap # current list of clean components
    clean_mask :: Vector{Int}      # mask for selecting clean components
    # information needed for cleaning
    workload :: Dict{Int, Int} # which worker owns which block of the observation matrix
    gaussian_kernel :: Alm     # convolution kernel for degrading the resolution
    wiener_mrange :: UnitRange # describes the Wiener filter applied to the data
end

function clean(spw, dataset, target)
    println("Initializing...")
    output_directory = joinpath(getdir(spw), "cleaning", target)
    isdir(output_directory) || mkdir(output_directory)

    @time _psf = load(joinpath(getdir(spw), "psf", "psf.jld"), "psf")
    major_σ, minor_σ, angle = load(joinpath(directory, "gaussian.jld"), "major", "minor", "angle")
    psf = FullPSF(_psf.pixels, _psf.amplitudes, major_σ, minor_σ, angle)

    @time residual_alm, wiener_mrange =
        load(joinpath(getdir(spw), "$target-$dataset.jld"), "alm", "mrange")
    observation_matrix_path = joinpath(getdir(spw), "observation-matrix-$dataset.jld")
    @time observation_matrix, cholesky_decomposition =
        load(observation_matrix_path, "blocks", "cholesky")
    @time workload = distribute_workload(observation_matrix, cholesky_decomposition)

    nside = 2048
    @time x, y, z = unit_vectors(nside)
    @time clean_mask = create_mask(spw, dataset, x, y, z)
    clean_components = HealpixMap(Float64, nside)

    @time gaussian_kernel = gaussian_alm(1, lmax(residual_alm), mmax(residual_alm), 512)
    @time degraded_alm = convolve(residual_alm, gaussian_kernel)
    @time residual_alm.alm[:] -= degraded_alm.alm
    @time residual_map = alm2map(residual_alm, nside)

    state = CleanState(lmax(residual_alm), mmax(residual_alm), nside, x, y, z,
                       residual_alm, residual_map, degraded_alm,
                       clean_components, clean_mask,
                       workload, gaussian_kernel, wiener_mrange)

    println("Cleaning...")
    major_iterations = 512 #2048
    minor_iterations = 256
    clean(state, psf, major_iterations, minor_iterations, output_directory)
end

function clean(state, psf, major_iterations, minor_iterations, output_directory)
    for iter = 1:major_iterations
        println("================")
        @printf("Iteration #%05d\n", iter)
        println("time = ", now())
        println("stddev = ", std(state.residual_map.pixels[state.clean_mask]))
        major_iteration!(state, psf, minor_iterations)
        mod(iter, 64) == 0 && in_progress_output(state, output_directory, iter)
    end
    save(joinpath(output_directory, "final.jld"),
         "residual_alm", state.residual_alm.alm, "residual_map", state.residual_map.pixels,
         "degraded_alm", state.degraded_alm.alm, "clean_components", state.clean_components.pixels,
         "clean_mask", state.clean_mask)
end

function in_progress_output(state, output_directory, iter)
    println("...writing maps...")
    iterstr = @sprintf("%05d", iter)
    filename = "residual-map-$iterstr.fits"
    writehealpix(joinpath(output_directory, filename), state.residual_map, replace=true)
    filename = "clean-components-$iterstr.fits"
    writehealpix(joinpath(output_directory, filename), state.clean_components, replace=true)
    filename = "degraded-map-$iterstr.fits"
    degraded_map = alm2map(state.degraded_alm, state.nside)
    writehealpix(joinpath(output_directory, filename), degraded_map, replace=true)
    save(joinpath(output_directory, "state-$iterstr.jld"),
         "residual_alm", state.residual_alm.alm, "residual_map", state.residual_map.pixels,
         "degraded_alm", state.degraded_alm.alm, "clean_components", state.clean_components.pixels,
         "clean_mask", state.clean_mask)
end

function major_iteration!(state, psf, minor_iterations)
    println("* selecting pixels")
    @time pixels = select_pixels(state, minor_iterations)
    println("* computing spherical harmonics")
    @time model_alm = compute_spherical_harmonics(state, psf, pixels)
    println("* corrupting spherical harmonics")
    @time corrupted_alm = corrupt_spherical_harmonics(state, model_alm)
    println("* removing clean components")
    @time remove_clean_components!(state, corrupted_alm)
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

function select_pixels(state, minor_iterations)
    select_pixels(state.residual_map, state.clean_mask,
                  state.x, state.y, state.z, minor_iterations)
end

function select_pixels(residual_map, clean_mask, x, y, z, minor_iterations)
    sorted_pixels = clean_mask[sortperm(abs2(residual_map.pixels[clean_mask]))]
    selected_pixels = Int[]
    while length(selected_pixels) < minor_iterations
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

function compute_spherical_harmonics(state, psf, pixels)
    compute_spherical_harmonics(state.residual_alm, state.residual_map,
                                state.clean_components, psf, pixels)
end

function compute_spherical_harmonics(residual_alm, residual_map,
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

function corrupt_spherical_harmonics(state, model_alm)
    corrupt_spherical_harmonics(model_alm, state.workload, state.wiener_mrange)
end

function corrupt_spherical_harmonics(model_alm, workload, wiener_mrange)
    output_alm = Alm(Complex128, lmax(model_alm), mmax(model_alm))
    function output(corrupted_alm, m)
        for l = m:lmax(model_alm)
            output_alm[l, m] = corrupted_alm[l-m+1]
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
    MModes.apply_wiener_filter!(output_alm, wiener_mrange)
    output_alm
end

function corrupt_spherical_harmonics_block(input_alm, m)
    observe_block(CleanWorker.observation_matrix_blocks[m],
                  CleanWorker.cholesky_decomposition_blocks[m],
                  input_alm)
end

function remove_clean_components!(state, corrupted_alm)
    remove_clean_components!(state.residual_alm, state.degraded_alm,
                             state.gaussian_kernel, corrupted_alm,
                             state.residual_map)
end

function remove_clean_components!(residual_alm, degraded_alm,
                                  gaussian_kernel, corrupted_alm,
                                  residual_map)
    degraded_corrupted_alm = convolve(corrupted_alm, gaussian_kernel)
    residual_corrupted_alm = corrupted_alm - degraded_corrupted_alm
    residual_alm.alm[:] -= residual_corrupted_alm.alm
    degraded_alm.alm[:] -= degraded_corrupted_alm.alm
    residual_map.pixels[:] = alm2map(residual_alm, nside(residual_map)).pixels
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

function gaussian_alm(fwhm, lmax=1000, mmax=1000, nside=512)
    # note: fwhm in degrees
    σ = fwhm/(2sqrt(2log(2)))
    kernel = HealpixMap(Float64, nside)
    for pix = 1:length(kernel)
        θ, ϕ = LibHealpix.pix2ang_ring(nside, pix)
        θ = rad2deg(θ)
        kernel[pix] = exp(-θ^2/(2σ^2))
    end
    dΩ = 4π/length(kernel)
    kernel = HealpixMap(kernel.pixels / (sum(kernel.pixels)*dΩ))
    map2alm(kernel, lmax, mmax, iterations=10)
end

function convolve(alm1, alm2)
    output_alm = Alm(Complex128, lmax(alm1), mmax(alm1))
    for m = 0:mmax(alm1), l = m:lmax(alm1)
        output_alm[l, m] = sqrt((4π)/(2l+1))*alm1[l, m]*alm2[l, 0]
    end
    output_alm
end

