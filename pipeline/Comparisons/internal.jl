function internal_comparison()
    widths = [4, 2, 1, 0.5]
    slope = Dict{Int, Vector{Float64}}()
    Δresidual = Dict{Int, Vector{Float64}}()
    jackknives = Dict{Int, Vector{Vector{Float64}}}()
    for width in widths
        @show width
        m, Δres = fit_plane_with_jackknife(width)
        slope[width] = m[1]
        Δresidual[width] = Δresidual[1]
        jackknives[width] = m[2:end]
    end
    save("internal-spectral-index-adaptive.jld",
         "slope", slope, "jackknives", jackknives, "delta_residual", Δresidual)
end

function fit_plane_with_jackknife(width)
    filename = "map-restored-registered-rainy-itrf.fits"
    filename_odd  = "map-odd-restored-registered-rainy-itrf.fits"
    filename_even = "map-even-restored-registered-rainy-itrf.fits"
    slopes = Vector{Float64}[]
    Δresidual = Vector{Float64}[]
    trials = [(filename, filename, filename),
              (filename, filename, filename_odd ),
              (filename, filename, filename_even),
              (filename_odd, filename,  filename),
              (filename_even, filename, filename)]
    futures = [remotecall(fit_plane, 1, trials[1]...)]
    for future in futures
        tmp = fetch(future)
        push!(slopes, tmp[1])
        push!(Δresiudal,  tmp[2])
    end
    slopes, Δresidual
end

function fit_plane(filename1, filename2, filename3; width=5)
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

    println("Fitting...")
    @time _fit_plane(map1, map2, map3, width)
end

function _fit_plane(map1, map2, map3, width)
    output_nside = 128
    output_npix  = nside2npix(output_nside)
    line_slope = zeros(output_npix) # slope of a linear fit between map1 and map3
    Δresidual  = zeros(output_npix) # change in residual between linear fit and planar fit

    meta = Pipeline.Common.getmeta(4, "rainy")
    frame = TTCal.reference_frame(meta)
    #prg = Progress(output_npix)
    for idx = 1:output_npix
        θ, ϕ = LibHealpix.pix2ang_ring(output_nside, idx)
        galactic = Direction(dir"GALACTIC", ϕ*radians, (π/2-θ)*radians)
        itrf = measure(frame, galactic, dir"ITRF")
        dec = latitude(itrf) |> rad2deg
        dec < -30 && @goto skip

        disc, weights = _disc_weights(map1, θ, ϕ, width)
        m, Δres = _fit_plane(map1, map2, map3, disc, weights)
        line_slope[idx] = m
        Δresidual[idx] = Δres

        @label skip
        #next!(prg)
    end
    line_slope, Δresidual
end

function _disc_weights(map, θ, ϕ, width)
    vec = LibHealpix.ang2vec(θ, ϕ)
    disc = LibHealpix.query_disc(map, θ, ϕ, deg2rad(width), inclusive=false)
    distance = Float64[]
    for jdx in disc
        vec′ = LibHealpix.pix2vec_ring(nside(map), Int(jdx))
        push!(distance, acosd(clamp(dot(vec, vec′), -1, 1)))
    end
    # we want a weighting function whose value and first derivative goes to exactly zero at
    # the boundary
    distance = clamp(distance, 0, width)
    distance = distance/width
    weights   = exp.(-0.5.*(distance./0.2).^2)
    weights .*= (1.+distance).^2 .* (1.-distance).^2 # truncates the Gaussian smoothly
    #weights = (cos(π*distance/width)+1)/2
    disc, weights
end

#using PyPlot

function _fit_plane(map1, map2, map3, disc, weights)
    e = ones(length(disc))
    x = [map1[pixel] for pixel in disc]
    y = [map2[pixel] for pixel in disc]
    z = [map3[pixel] for pixel in disc]
    W = Diagonal(weights)

    # Fit a line
    A = [x e]
    m_line = (A'*W*A)\(A'*(W*z))
    z_ = m_line[1]*x + m_line[2]
    residual_line = sqrt(sum(abs2(z-z_)))

    # Fit a plane
    A = [x y e]
    m_plane = (A'*W*A)\(A'*(W*z))
    z_ = m_plane[1]*x + m_plane[2]*y + m_plane[3]
    residual_plane = sqrt(sum(abs2(z-z_)))

    ## Wow, the line fit is shitty, let's fit two lines
    ## Note: I'm doing this because I can't figure out how to reliably turn the parameters of the
    ##       plane into a spectral index. There isn't an algebraic relation to do it.
    #if abs(residual_line-residual_plane)/abs(residual_plane) > 0.5
    #    function objective(p, _)
    #        res1 = abs2(z - (p[1]*x + p[2]))
    #        res2 = abs2(z - (p[3]*x + p[4]))
    #        output = 0.0
    #        for idx = 1:length(z)
    #            output += weights[idx]*min(res1[idx], res2[idx])
    #        end
    #        output
    #    end

    #    opt = Opt(:LN_SBPLX, 4)
    #    xtol_rel!(opt, 1e-5)
    #    min_objective!(opt, objective)
    #    minf, params, ret = optimize(opt, [m_line[1], m_line[2], m_line[1], m_line[2]])

    #    #figure(1); clf()
    #    #scatter(x, z, c=y, s=weights, vmin=minimum(z), vmax=maximum(z))
    #    #x_ = [minimum(x), maximum(x)]
    #    #z_ = m_line[1]*x_ + m_line[2]
    #    #plot(x_, z_, "k-")
    #    #z_ = params[1]*x_ + params[2]
    #    #plot(x_, z_, "r-")
    #    #z_ = params[3]*x_ + params[4]
    #    #plot(x_, z_, "r-")
    #    #xlim(minimum(x), maximum(x))
    #    #ylim(minimum(z), maximum(z))

    #    funky_slope_1 = max(params[1], params[3])
    #    funky_slope_2 = min(params[1], params[3])
    #else
    #    funky_slope_1 = 0.0
    #    funky_slope_2 = 0.0
    #end

    #figure(1); clf()
    #scatter(x, z, c=y, s=weights, vmin=minimum(z), vmax=maximum(z))
    #colorbar()
    #x_ = [minimum(x), maximum(x)]
    #z_ = m_line[1]*x_ + m_line[2]
    #plot(x_, z_, "k-")
    #xlim(minimum(x), maximum(x))
    #ylim(minimum(z), maximum(z))
    #@show m_line m_plane
    #@show residual_line residual_plane

    Δresidual = abs(residual_line-residual_plane)/abs(residual_plane)
    m_line[1], Δresidual
end

