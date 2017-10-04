#filename = "map-restored-registered-rainy-itrf.fits"
#filename_odd  = "map-odd-restored-registered-rainy-itrf.fits"
#filename_even = "map-even-restored-registered-rainy-itrf.fits"

function internal_comparison(filename1="map-restored-registered-rainy-itrf.fits",
                             filename2="map-restored-registered-rainy-itrf.fits")
    width = 20.0
    @time slope, R², mask = internal_powerlaw_fit(filename1, filename2, width)

    filename = "internal-spectral-index-updated"
    save(filename*".jld", "slope", slope, "coefficient-of-determination", R², "mask", mask)
end

function internal_powerlaw_fit(filename1, filename2, width)
    #println("Preparing 1...")
    #ν1 = Pipeline.Common.getfreq(4)
    #@time map1 = readhealpix(joinpath(Pipeline.Common.getdir(4), filename1))
    #@time map1 = map1 * (BPJSpec.Jy * (BPJSpec.c/ν1)^2 / (2*BPJSpec.k))
    #@time map1 = Pipeline.MModes.rotate_to_galactic(4, "rainy", map1)
    #@time map1 = degrade(map1, 512)

    #println("Preparing 3...")
    #ν3 = Pipeline.Common.getfreq(18)
    #@time map3 = readhealpix(joinpath(Pipeline.Common.getdir(18), filename2))
    #@time map3 = map3 * (BPJSpec.Jy * (BPJSpec.c/ν3)^2 / (2*BPJSpec.k))
    #@time map3 = Pipeline.MModes.rotate_to_galactic(18, "rainy", map3)
    #@time map3 = degrade(map3, 512)

    #save("internal-spectra-checkpoint.jld",
    #     "map1", map1.pixels, "map2", map2.pixels, "map3", map3.pixels)

    map1_pixels, map3_pixels =
        load("internal-spectra-checkpoint.jld", "map1", "map3")
    map1 = HealpixMap(map1_pixels)
    map3 = HealpixMap(map3_pixels)

    println("Constructing mask...")
    mask = _construct_mask(nside(map1))

    println("Fitting...")
    _internal_powerlaw_fit(map1, map3, mask, width)
end

function _construct_mask(nside)
    Npix = nside2npix(nside)
    mask = zeros(Bool, Npix)

    meta = Pipeline.Common.getmeta(4, "rainy")
    frame = TTCal.reference_frame(meta)
    sun = measure(frame, Direction(dir"SUN"), dir"GALACTIC")
    sun_vec = [sun.x, sun.y, sun.z]

    ncp = measure(frame, Direction(dir"ITRF", 0, 0, 1), dir"GALACTIC")
    ncp_vec = [ncp.x, ncp.y, ncp.z]

    for pix = 1:Npix
        vec = LibHealpix.pix2vec_ring(nside, pix)
        θ, ϕ = LibHealpix.vec2ang(vec)
        galactic_latitude = π/2-θ
        #if abs(galactic_latitude) < deg2rad(5)
        #    mask[pix] = true
        if dot(vec, ncp_vec) < cosd(120)
            mask[pix] = true
        elseif dot(vec, sun_vec) > cosd(2)
            mask[pix] = true
        end
    end
    mask
end

function _internal_powerlaw_fit(map1, map2, mask, width; output_nside = 256)
    #output_nside = 256 # 32 for testing, 256 for production
    output_npix  = nside2npix(output_nside)

    slope = zeros(output_npix) # slope of a linear fit between map1 and map2
    R²    = zeros(output_npix) # coefficient of determination

    N = nworkers()
    workloads = [idx:N:output_npix for idx = 1:N]
    futures = [remotecall(_internal_powerlaw_fit, worker,
                          map1, map2, mask, width, workload, output_nside)
               for (worker, workload) in zip(workers(), workloads)]
    for (workload, future) in zip(workloads, futures)
        slope_, R²_ = fetch(future)
        slope[workload] = slope_[workload]
        R²[workload] = R²_[workload]
    end

    slope, R², mask
end

function _internal_powerlaw_fit(map1, map2, mask, width, workload, output_nside)
    output_npix  = nside2npix(output_nside)
    input_nside = nside(map1)
    input_npix  = nside2npix(input_nside)

    slope = zeros(output_npix) # slope of a linear fit between map1 and map2
    R²    = zeros(output_npix) # coefficient of determination

    meta = Pipeline.Common.getmeta(4, "rainy")
    frame = TTCal.reference_frame(meta)
    for idx in workload
        θ, ϕ = LibHealpix.pix2ang_ring(output_nside, idx)
        jdx = LibHealpix.ang2pix_ring(input_nside, θ, ϕ)
        mask[jdx] && continue
        disc, weights = _disc_weights(map1, mask, θ, ϕ, width)
        slope[idx], R²[idx] = internal_fit_line(idx, map1, map2, disc, weights)
    end
    slope, R²
end

function _disc_weights(map, mask, θ, ϕ, width)
    vec = LibHealpix.ang2vec(θ, ϕ)
    disc = LibHealpix.query_disc(map, θ, ϕ, deg2rad(width), inclusive=false)
    weights = Float64[]
    for jdx in disc
        if mask[jdx]
            push!(weights, 0)
        else
            vec′ = LibHealpix.pix2vec_ring(nside(map), Int(jdx))
            distance = acosd(clamp(dot(vec, vec′), -1, 1))
            distance = clamp(distance, 0, width)
            distance = distance/width
            weight   = exp(-0.5*(distance/0.2)^2)
            weight  *= (1+distance)^2 * (1-distance)^2 # truncates the Gaussian smoothly
            push!(weights, weight)
        end
    end
    disc, weights
end

function internal_fit_line(idx, map1, map2, disc, weights)
    #@show idx
    x = [map1[pixel] for pixel in disc]
    y = [map2[pixel] for pixel in disc]

    # Fit a line
    e = ones(length(x))
    A = [x e]
    W = Diagonal(weights)
    m_line = (A'*W*A)\(A'*(W*y))
    y_ = m_line[1]*x + m_line[2]

    slope = m_line[1]
    R² = 1 - sum(weights.*abs2(y-y_))/sum(weights.*abs2(y-mean(y)))
    slope, R²
end

