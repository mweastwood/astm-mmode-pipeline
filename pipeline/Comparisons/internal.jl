function better_internal_comparison()
    freq = [Pipeline.Common.getfreq(spw) for spw = 4:2:18]
    #maps = [prepare_lwa_map(spw, "map-restored-registered-rainy-itrf.fits") for spw = 4:2:18]
    #save("better-internal-spectra-checkpoint.jld", "maps", getfield.(maps, 1))
    maps = HealpixMap.(load("better-internal-spectra-checkpoint.jld", "maps"))
    spectral_index, amplitude = power_law_fit(freq, maps)
    save("better-spectral-index.jld", "spectral_index", spectral_index, "amplitude", amplitude)
end

function power_law_fit(freq, maps)
    Npix = length(maps[1])
    Nworkers = length(workers())

    spectral_index = zeros(Npix)
    amplitude = zeros(Npix)

    futures = [remotecall(power_law_fit, worker, freq, maps, idx:Nworkers:Npix)
               for (idx, worker) in enumerate(workers())]
    for future in futures
        _spectral_index, _amplitude, pixels = fetch(future)
        spectral_index[pixels] = _spectral_index[pixels]
        amplitude[pixels] = _amplitude[pixels]
    end
    spectral_index, amplitude
end

function power_law_fit(freq, maps, pixels)
    N = length(maps[1])
    spectral_index = zeros(N)
    amplitude = zeros(N)
    meta = Pipeline.Common.getmeta(4, "rainy")
    frame = TTCal.reference_frame(meta)
    @time for pixel in pixels
        θ, ϕ = LibHealpix.pix2ang_ring(nside(maps[1]), pixel)
        galactic = Direction(dir"GALACTIC", ϕ*radians, (π/2-θ)*radians)
        itrf = measure(frame, galactic, dir"ITRF")
        dec = latitude(itrf) |> rad2deg
        dec < -30 && continue

        disc1 = LibHealpix.query_disc(maps[1], θ, ϕ, deg2rad(2))
        disc2 = LibHealpix.query_disc(maps[1], θ, ϕ, deg2rad(5))
        annulus = setdiff(disc2, disc1)
        flux = [map[pixel] - median(map[annulus]) for map in maps]
        if all(flux .> 0)
            spectral_index[pixel], amplitude[pixel] = _power_law_fit(freq, flux)
        else
            spectral_index[pixel] = NaN
            amplitude[pixel] = NaN
        end
    end
    spectral_index, amplitude, pixels
end

function _power_law_fit(freq, flux)
    x = log(freq)
    y = log(flux)
    e = ones(length(freq))
    A = [x e]
    coeff = A\y
    spectral_index = coeff[1]
    amplitude = exp(coeff[2])
    spectral_index, amplitude
end

function prepare_lwa_map(spw, filename)
    ν = Pipeline.Common.getfreq(spw)
    map = readhealpix(joinpath(Pipeline.Common.getdir(spw), filename))
    map = map * (BPJSpec.Jy * (BPJSpec.c/ν)^2 / (2*BPJSpec.k))
    map = Pipeline.MModes.rotate_to_galactic(spw, "rainy", map)
    map = degrade(map, 512)
    map
end


function internal_comparison()
    widths = [20.0]
    slope = Dict{Float64, Vector{Float64}}()
    Δresidual = Dict{Float64, Vector{Float64}}()
    jackknives = Dict{Float64, Vector{Vector{Float64}}}()
    for width in widths
        m, Δres = fit_plane_with_jackknife(width)
        slope[width] = m[1]
        Δresidual[width] = Δres[1]
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
    futures = [remotecall(fit_plane, idx+1, trials[idx]..., width) for idx = 1:length(trials)]
    for future in futures
        tmp = fetch(future)
        push!(slopes, tmp[1])
        push!(Δresidual,  tmp[2])
    end
    slopes, Δresidual
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

    println("Fitting...")
    @time _fit_plane(map1, map2, map3, width)
end

function _fit_plane(map1, map2, map3, width)
    output_nside = 256
    output_npix  = nside2npix(output_nside)
    line_slope = zeros(output_npix) # slope of a linear fit between map1 and map3
    Δresidual  = zeros(output_npix) # change in residual between linear fit and planar fit

    meta = Pipeline.Common.getmeta(4, "rainy")
    frame = TTCal.reference_frame(meta)
    for idx = 1:output_npix
        θ, ϕ = LibHealpix.pix2ang_ring(output_nside, idx)
        galactic = Direction(dir"GALACTIC", ϕ*radians, (π/2-θ)*radians)
        itrf = measure(frame, galactic, dir"ITRF")
        dec = latitude(itrf) |> rad2deg
        dec < -30 && continue

        disc, weights = _disc_weights(map1, θ, ϕ, width)
        m, Δres = _fit_plane(idx, map1, map2, map3, disc, weights)
        line_slope[idx] = m
        Δresidual[idx] = Δres
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

