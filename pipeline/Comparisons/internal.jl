function internal_comparison()
    width = 20.0
    m, res, masks = fit_plane_with_jackknife(width)
    slope = m[1]
    residual = res[1]
    jackknives = m[2:end]

    save("internal-spectral-index.jld",
         "slope", slope, "jackknives", jackknives, "residual", residual,
         "masks", masks)
end

function fit_plane_with_jackknife(width)
    filename = "map-restored-registered-rainy-itrf.fits"
    filename_odd  = "map-odd-restored-registered-rainy-itrf.fits"
    filename_even = "map-even-restored-registered-rainy-itrf.fits"
    slopes = Vector{Float64}[]
    residual = Vector{Float64}[]
    masks = Vector{Bool}[]
    trials = [(filename, filename, filename),
              (filename, filename, filename_odd ),
              (filename, filename, filename_even),
              (filename_odd, filename,  filename),
              (filename_even, filename, filename)]
    futures = [remotecall(fit_plane, idx+1, trials[idx]..., width) for idx = 1:length(trials)]
    for future in futures
        tmp = fetch(future)
        push!(slopes, tmp[1])
        push!(residual,  tmp[2])
        push!(masks,  tmp[3])
    end
    slopes, residual, masks
end

function fit_plane(filename1, filename2, filename3, width)
    #println("Preparing 1...")
    #ν1 = Pipeline.Common.getfreq(4)
    #@time map1 = readhealpix(joinpath(Pipeline.Common.getdir(4), filename1))
    #@time map1 = map1 * (BPJSpec.Jy * (BPJSpec.c/ν1)^2 / (2*BPJSpec.k))
    #@time map1 = Pipeline.MModes.rotate_to_galactic(4, "rainy", map1)
    #@time map1 = degrade(map1, 512)

    #println("Preparing 2...")
    #ν2 = Pipeline.Common.getfreq(10)
    #@time map2 = readhealpix(joinpath(Pipeline.Common.getdir(10), filename2))
    #@time map2 = map2 * (BPJSpec.Jy * (BPJSpec.c/ν2)^2 / (2*BPJSpec.k))
    #@time map2 = Pipeline.MModes.rotate_to_galactic(4, "rainy", map2)
    #@time map2 = degrade(map2, 512)

    #println("Preparing 3...")
    #ν3 = Pipeline.Common.getfreq(18)
    #@time map3 = readhealpix(joinpath(Pipeline.Common.getdir(18), filename1))
    #@time map3 = map3 * (BPJSpec.Jy * (BPJSpec.c/ν3)^2 / (2*BPJSpec.k))
    #@time map3 = Pipeline.MModes.rotate_to_galactic(4, "rainy", map3)
    #@time map3 = degrade(map3, 512)

    #save("internal-spectra-checkpoint.jld",
    #     "map1", map1.pixels, "map2", map2.pixels, "map3", map3.pixels)

    map1_pixels, map2_pixels, map3_pixels =
        load("internal-spectra-checkpoint.jld", "map1", "map2", "map3")
    map1 = HealpixMap(map1_pixels)
    map2 = HealpixMap(map2_pixels)
    map3 = HealpixMap(map3_pixels)

    println("Constructing mask...")
    mask = _construct_mask(nside(map1))

    println("Fitting...")
    @time _fit_plane(map1, map2, map3, mask, width)
end

function _construct_mask(nside)
    Npix = nside2npix(nside)
    mask = zeros(Bool, Npix)

    meta = Pipeline.Common.getmeta(4, "rainy")
    frame = TTCal.reference_frame(meta)
    sun = measure(frame, Direction(dir"SUN"), dir"GALACTIC")
    sun_vec = [sun.x, sun.y, sun.z]

    for pix = 1:Npix
        vec = LibHealpix.pix2vec_ring(nside, pix)
        θ, ϕ = LibHealpix.vec2ang(vec)
        latitude = π/2-θ

        if abs(latitude) < deg2rad(5)
            mask[pix] = true
        elseif dot(vec, sun_vec) > cosd(2)
            mask[pix] = true
        end
    end
    mask
end

function _fit_plane(map1, map2, map3, mask, width)
    output_nside = 256
    output_npix  = nside2npix(output_nside)
    line_slope = zeros(output_npix) # slope of a linear fit between map1 and map3
    residual  = zeros(output_npix) # change in residual between linear fit and planar fit

    meta = Pipeline.Common.getmeta(4, "rainy")
    frame = TTCal.reference_frame(meta)
    for idx = 1:output_npix
        mask[idx] && continue

        θ, ϕ = LibHealpix.pix2ang_ring(output_nside, idx)
        galactic = Direction(dir"GALACTIC", ϕ*radians, (π/2-θ)*radians)
        itrf = measure(frame, galactic, dir"ITRF")
        dec = latitude(itrf) |> rad2deg
        dec < -30 && continue

        disc, weights = _disc_weights(map1, mask, θ, ϕ, width)
        m, res = _fit_plane(idx, map1, map2, map3, disc, weights)
        line_slope[idx] = m
        residual[idx] = res
    end
    line_slope, residual, mask
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

function _fit_plane(idx, map1, map2, map3, disc, weights)
    #@show idx
    x = [map1[pixel] for pixel in disc]
    y = [map2[pixel] for pixel in disc]
    z = [map3[pixel] for pixel in disc]

    # Discard extreme points (to reduce sensitivty to point sources)
    N = length(z)
    amplitude = hypot.(x, y, z)
    perm = sortperm(amplitude)
    perm = perm[1:round(Int, 0.9N)]
    x = x[perm]
    y = y[perm]
    z = z[perm]
    weights = weights[perm]

    #μx = mean(x)
    #μz = mean(z)
    #σx = std(x)
    #σz = std(z)
    #σxz = mean((x-μx).*(z-μz))
    #ρ = σxz/(σx*σz)

    #weights[:] = 1

    # Fit a line
    e = ones(length(x))
    A = [x e]
    W = Diagonal(weights)
    m_line = (A'*W*A)\(A'*(W*z))
    z_ = m_line[1]*x + m_line[2]
    weight_norm = sqrt(sum(weights))
    residual_norm = sqrt(sum(weights.*abs2(z-z_)))
    data_norm = sqrt(sum(weights.*abs2(z)))

    ###if residual_norm > 0.5
    #if m_line[1] < 0
    #    @show idx
    #    function objective(p, _)
    #        res1 = abs2(z - (p[1]*x + p[2]))
    #        res2 = abs2(z - (p[3]*x + p[4]))
    #        output = 0.0
    #        for jdx = 1:length(z)
    #            output += weights[jdx]*min(res1[jdx], res2[jdx])
    #        end
    #        @show p, output
    #        output
    #    end

    #    opt = Opt(:LN_SBPLX, 4)
    #    ftol_rel!(opt, 1e-5)
    #    min_objective!(opt, objective)
    #    minf, params, ret = optimize(opt, [m_line[1], m_line[2], m_line[1], m_line[2]])

    #    @show idx
    #    @show N
    #    @show m_line
    #    #@show params
    #    @show residual_norm data_norm weight_norm
    #    
    #    figure(1); clf()
    #    scatter(x, z, c=y, s=10weights, vmin=minimum(z), vmax=maximum(z))
    #    x_ = [minimum(x), maximum(x)]
    #    z_ = m_line[1]*x_ + m_line[2]
    #    plot(x_, z_, "k-")
    #    z_ = params[1]*x_ + params[2]
    #    plot(x_, z_, "r-")
    #    z_ = params[3]*x_ + params[4]
    #    plot(x_, z_, "r-")
    #    xlim(minimum(x), maximum(x))
    #    ylim(minimum(z), maximum(z))

    #    print("Continue? ")
    #    inp = chomp(readline())
    #    inp == "q" && error("stop")
    #end

    m_line[1], residual_norm/data_norm
end

