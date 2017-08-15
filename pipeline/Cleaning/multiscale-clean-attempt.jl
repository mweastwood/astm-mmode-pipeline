immutable UnitVectors
    x :: Vector{Float64}
    y :: Vector{Float64}
    z :: Vector{Float64}
end

abstract AbstractScale

immutable ZeroScale <: AbstractScale
    fwhm :: Float64 # always zero
    unit_vectors :: UnitVectors
    mask :: Vector{Bool}
    components :: HealpixMap
    residual_alm :: Alm
    residual_map :: HealpixMap
end

function initialize_zero_scale(dataset, original_alm)
    nside = 2048
    unit_vectors = get_unit_vectors(nside)
    mask = create_mask(dataset, unit_vectors)
    components = HealpixMap(Float64, nside)
    residual_alm = deepcopy(original_alm)
    residual_map = alm2map(residual_alm, nside)
    ZeroScale(0, unit_vectors, mask, components, residual_alm, residual_map)
end

immutable Scale <: AbstractScale
    fwhm :: Float64 # degrees
    unit_vectors :: UnitVectors
    kernel :: Alm
    mask :: Vector{Bool}
    components :: HealpixMap
    residual_alm :: Alm
    residual_map :: HealpixMap
end

function initialize_scale(dataset, original_alm, fwhm)
    nside = fwhm < 1 ? 2048 : 512
    unit_vectors = get_unit_vectors(nside)
    kernel = gaussian_alm(fwhm, lmax(original_alm), mmax(original_alm), nside)
    mask = create_mask(dataset, unit_vectors)
    components = HealpixMap(Float64, nside)
    residual_alm = convolve(original_alm, kernel)
    residual_map = alm2map(residual_alm, nside)
    Scale(fwhm, unit_vectors, kernel, mask, components, residual_alm, residual_map)
end

immutable CleanState
    output_directory :: String
    scales :: Vector{AbstractScale}
    workload :: Dict{Int, Int} # which worker owns each value of m
    wiener_mrange :: UnitRange{Int} # which coefficients were Wiener filtered
end

function initialize(spw, dataset, target, fwhm_scales)
    output_directory = joinpath(getdir(spw), "cleaning")
    isdir(output_directory) || mkdir(output_directory)

    @time psf = load(joinpath(getdir(spw), "psf", "psf.jld"), "psf")
    @time original_alm, wiener_mrange =
        load(joinpath(getdir(spw), "$target-$dataset.jld"), "alm", "mrange")

    @time zeroscale = initialize_zero_scale(dataset, original_alm)
    @time scales = AbstractScale[initialize_scale(dataset, original_alm, fwhm) for fwhm in fwhm_scales]
    unshift!(scales, zeroscale)

    for scale in scales
        writehealpix(joinpath(output_directory, @sprintf("initial-%02d.fits", scale.fwhm)),
                     scale.residual_map, replace=true)
    end

    observation_matrix_path = joinpath(getdir(spw), "observation-matrix-$dataset.jld")
    @time observation_matrix, cholesky_decomposition =
        load(observation_matrix_path, "blocks", "cholesky")
    @time workload = distribute_workload(observation_matrix, cholesky_decomposition)

    # NOTE: the PSF is not included in the CleanState type to prevent issues where after reloading
    # the module, the PSF type has "changed".
    CleanState(output_directory, scales, workload, wiener_mrange), psf
end

function clean(spw, dataset, target)
    println("Initializing...")
    @time state, psf = initialize(spw, dataset, target, [1.0, 4.0])

    major_iterations = 1 # 2048
    minor_iterations = 256 # 256

    println("Cleaning...")
    _clean(state, psf, major_iterations, minor_iterations)
end

function _clean(state, psf, major_iterations, minor_iterations)
    for iter = 1:major_iterations
        println("================")
        @printf("Iteration %05d of %05d\n", iter, major_iterations)
        println("time = ", now())

        @time major_iteration!(state, psf, minor_iterations)

        #if mod(iter, 128) == 0
        #    println("...writing maps...")
        #    dir = getdir(spw)
        #    iterstr = @sprintf("%05d", iter)
        #    filename = "residual-map-$iterstr.fits"
        #    writehealpix(joinpath(output_directory, filename), residual_map, replace=true)
        #    filename = "clean-components-$iterstr.fits"
        #    writehealpix(joinpath(output_directory, filename), clean_components, replace=true)
        #end
    end

    #save(joinpath(output_directory, "final.jld"),
    #     "residual_alm", residual_alm.alm,
    #     "residual_map", residual_map.pixels,
    #     "clean_components", clean_components.pixels)
end

function major_iteration!(state, psf, minor_iterations)

    println("* selecting components")
    #@time components = select_components(state, minor_iterations)
    #@show components length(components)
    components = Tuple{Int64,Int64}[(1,8435542),(1,2498094),(1,9591212),(1,24513573),(1,15060450),(1,9607332),(1,14116609),(1,9056573),(1,6386262),(1,9128156),(1,6225938),(1,36760242),(1,14454635),(1,24224651),(1,35031787),(3,2355864),(1,9629729),(1,7159179),(1,15407945),(1,13685353),(1,396707),(1,7325192),(1,13041733),(3,2206371),(1,29543331),(1,20527156),(1,5275931),(1,22046533),(1,12660226),(1,7958157),(3,2282182),(1,25930707),(3,2392753),(1,3182653),(3,2089664),(1,5975275),(1,7957574),(1,19281004),(3,2445969),(1,22727762),(1,5278782),(1,30330965),(1,16086281),(1,19811490),(3,2157267),(1,24258633),(1,50366),(1,11985555),(1,3520267),(3,2265742),(1,8924682),(1,14056244),(3,2376318),(1,4438618),(1,15871261),(1,20802538),(3,2509437),(1,8774115),(1,21130363),(1,21872629),(3,2106024),(1,11545517),(1,2176797),(3,2009808),(1,16687761),(1,683205),(1,6654900),(3,1723134),(1,17692446),(1,30755723),(1,22586196),(1,42082945),(3,1743586),(1,14843312),(1,3578429),(1,27671423),(3,1827538),(3,1641230),(1,1754548),(3,2077410),(1,22334625),(3,1635038),(3,2482859),(1,17681344),(1,7177282),(1,12948864),(1,3764935),(1,32436364),(3,2574954),(1,16705043),(3,2249438),(1,19459129),(1,5279911),(1,13906978),(1,5735564),(3,2378444),(1,4748616),(1,15956968),(1,11966827),(1,15669845),(3,1434366),(3,1985209),(1,13250528),(1,24022372),(1,14367137),(3,2546327),(1,13212188),(1,19987589),(3,1516270),(3,1831680),(1,11467304),(3,1504036),(1,16028255),(1,18050250),(3,2441834),(2,1348365),(1,8023795),(3,1721035),(1,3615627),(3,1878718),(1,34212415),(1,4677100),(1,16492558),(1,20199560),(1,20310787),(1,9034051),(1,10486225),(3,2169582),(1,18799457),(1,11925075),(1,9707307),(1,17524910),(1,7686310),(1,19091598),(1,453130),(1,35064281),(1,14886810),(1,14473709),(1,11334928),(3,1774263),(1,3207588),(1,1058916),(3,1749780),(3,1319737),(3,2568780),(1,11011509),(1,7057058),(1,14654691),(3,1528535),(1,14306663),(1,873549),(1,4851278),(1,2311036),(1,22427352),(3,1614628),(1,4321309),(3,1940219),(1,15991726),(1,6919314),(1,19103422),(3,1612488),(1,3836179),(1,1101397),(3,2470599),(1,175225),(1,11842676),(1,9725475),(1,2213730),(1,22239811),(1,1401882),(1,13550713),(3,2290290),(1,14400583),(1,9372950),(1,2366085),(1,7033545),(1,18099327),(1,2451638),(1,5599969),(1,21048194),(1,10395593),(1,22931806),(1,22291965),(1,5362305),(3,2613892),(1,2667521),(1,41084110),(3,2003617),(1,14508483),(1,6296605),(1,14490521),(1,10096182),(1,2687525),(1,4740296),(1,25581480),(3,1471290),(1,5636347),(3,2574895),(1,19144662),(1,26022082),(1,349302),(1,8711564),(1,25654477),(1,10570950),(3,1426145),(1,11182938),(1,11455851),(3,1665716),(3,2482769),(1,16903413),(1,12734556),(1,1068723),(1,6414268),(1,26484200),(3,2345701),(3,1899175),(1,9074350),(3,2353759),(1,7748580),(1,4578865),(1,2800160),(1,18262290),(1,23294445),(1,18297688),(1,18056159),(1,5990232),(1,4734810),(1,2629143),(1,13445337),(1,18197547),(1,13798681),(1,1154535),(1,2523638),(1,381216),(1,40114016),(1,12430486),(3,1215297),(1,3201976),(1,7072450),(1,620003),(1,2763736),(3,2046714),(1,649918),(3,1508032),(1,15461569),(1,9682231),(1,21039629),(3,1374881),(3,1858327),(1,5321649),(1,12820013),(3,2554556),(1,8951067),(1,6587201),(3,2644314),(1,3779756)]

    println("* computing spherical harmonics")
    @time model_alm = compute_spherical_harmonics!(state, psf, components)

    println("* corrupting spherical harmonics")
    @time corrupt_spherical_harmonics!(model_alm, state.workload, state.wiener_mrange)

    writehealpix("model.fits", alm2map(model_alm, 2048), replace=true)

#    println("* removing clean components")
#    @time residual_alm.alm[:] -= model_alm.alm
#
#    println("* creating new residual map")
#    @time residual_map = alm2map(residual_alm, nside(residual_map))
#
#    residual_map
end

function create_mask(dataset, unit_vectors)
    N = length(unit_vectors.x)
    mask = zeros(Bool, N)
    meta = getmeta(4, dataset)
    frame = TTCal.reference_frame(meta)
    #_per_a = measure(frame, Direction(dir"J2000", "03h19m48.16010s", "+41d30m42.1031s"), dir"ITRF")
    #_3c134 = measure(frame, Direction(dir"J2000", "05h04m42.0s", "+38d06m02s"), dir"ITRF")
    for pixel = 1:N
        declination = acosd(unit_vectors.z[pixel])
        #dotproduct = x[pixel]*_3c134.x + y[pixel]*_3c134.y + z[pixel]*_3c134.z
        #distance = acosd(clamp(dotproduct, -1, 1))
        if declination > -30 #&& distance < 0.5
            mask[pixel] = true
        end
    end
    mask
end

function sort_pixels(scale::AbstractScale, minor_iterations)
    pixels = find(scale.mask)
    values = abs2(scale.residual_map[scale.mask])
    perm = sortperm(values, rev=true)
    pixels[perm], values[perm]
end

function sort_pixels(state::CleanState, minor_iterations)
    pixels = Vector{Int}[]
    values = Vector{Float64}[]
    for scale in state.scales
        _pixels, _values = sort_pixels(scale, minor_iterations)
        push!(pixels, _pixels)
        push!(values, _values)
    end
    pixels, values
end

function select_components(state, minor_iterations)
    @time pixels, values = sort_pixels(state, minor_iterations)

    max_fwhm = maximum(scale.fwhm for scale in state.scales)
    bias = [1-0.6*scale.fwhm/max_fwhm for scale in state.scales]

    selected_fwhm = Float64[]
    selected_components = Tuple{Int, Int}[]
    selected_directions = Tuple{Float64, Float64, Float64}[]
    @time while length(selected_components) < minor_iterations && !any(isempty.(pixels))
        @label top
        any(isempty.(pixels)) && break

        peaks = first.(values) ./ bias
        scale_index = indmax(peaks)
        scale = state.scales[scale_index]
        peak_pixel = shift!(pixels[scale_index])
        peak_value = shift!(values[scale_index])

        fwhm = scale.fwhm
        x = scale.unit_vectors.x[peak_pixel]
        y = scale.unit_vectors.y[peak_pixel]
        z = scale.unit_vectors.z[peak_pixel]

        # verify we're not too close to other already selected pixels
        for idx = 1:length(selected_components)
            direction = selected_directions[idx]
            dotproduct = x*direction[1] + y*direction[2] + z*direction[3]
            dotproduct = clamp(dotproduct, -1, 1)
            distance = acosd(dotproduct)
            if distance < max(3, fwhm, selected_fwhm[idx])
                @goto top
            end
        end

        push!(selected_fwhm, fwhm)
        push!(selected_components, (scale_index, peak_pixel))
        push!(selected_directions, (x, y, z))
    end

    selected_components
end

function compute_spherical_harmonics!(state, psf, components)
    lmax = mmax = 1000
    model_alm = Alm(Complex128, lmax, mmax)
    function add_component(component_alm, scale, pixel)
        ring = searchsortedlast(psf.pixels, pixel)
        #chunk = 0.15*scale.residual_map[pixel]/(psf.amplitudes[ring]/gaussian_amplitude_correction[scale.fwhm])
        chunk = scale.residual_map[pixel]/(psf.amplitudes[ring])#/gaussian_amplitude_correction[scale.fwhm])
        scale.components[pixel] += chunk
        model_alm.alm[:] += chunk*component_alm.alm
    end

    next_component() = shift!(components)
    done() = length(components) == 0
    @sync for worker in workers()
        @async while !done()
            scale_index, pixel = next_component()
            scale = state.scales[scale_index]
            θ, ϕ = LibHealpix.pix2ang_ring(nside(scale.residual_map), pixel)
            component_alm = remotecall_fetch(pointsource_alm, worker, θ, ϕ, lmax, mmax)
            if scale.fwhm != 0
                component_alm = convolve(component_alm, scale.kernel)
            end
            add_component(component_alm, scale, pixel)
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

function empty_blocks()
    empty!(CleanWorker.observation_matrix_blocks)
    empty!(CleanWorker.cholesky_decomposition_blocks)
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

function get_unit_vectors(nside)
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
    UnitVectors(x, y, z)
end

function rotate_alm!(alm, dϕ)
    for m = 0:mmax(alm)
        cismdϕ = cis(-m*dϕ)
        for l = m:lmax(alm)
            alm[l, m] *= cismdϕ
        end
    end
end

const gaussian_amplitude_correction = Dict{Float64, Float64}(0.0 => 1.0)

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
    gaussian_amplitude_correction[fwhm] = sum(kernel.pixels)
    kernel = HealpixMap(kernel.pixels / gaussian_amplitude_correction[fwhm] / dΩ)
    map2alm(kernel, lmax, mmax, iterations=10)
end

function convolve(alm1, alm2)
    output_alm = Alm(Complex128, lmax(alm1), mmax(alm1))
    for m = 0:mmax(alm1), l = m:lmax(alm1)
        output_alm[l, m] = sqrt((4π)/(2l+1))*alm1[l, m]*alm2[l, 0]
    end
    output_alm
end

function degrade(alm, fwhm, nside=512)
    # note: fwhm in degrees
    # spherical convolution: https://www.cs.jhu.edu/~misha/Spring15/17.pdf
    σ = fwhm/(2sqrt(2log(2)))
    kernel = HealpixMap(Float64, nside)
    for pix = 1:length(kernel)
        θ, ϕ = LibHealpix.pix2ang_ring(nside, pix)
        θ = rad2deg(θ)
        kernel[pix] = exp(-θ^2/(2σ^2))
    end
    dΩ = 4π/length(kernel)
    kernel = HealpixMap(kernel.pixels / (sum(kernel.pixels)*dΩ))

    kernel_alm = map2alm(kernel, lmax(alm), mmax(alm), iterations=10)
    output_alm = Alm(Complex128, lmax(alm), mmax(alm))
    for m = 0:mmax(alm), l = m:lmax(alm)
        output_alm[l, m] = sqrt((4π)/(2l+1))*alm[l, m]*kernel_alm[l, 0]
    end
    output_alm
end

