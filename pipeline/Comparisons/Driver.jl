module Driver

include("../Pipeline.jl")

using PyPlot
using JLD
using LibHealpix
using CasaCore.Measures
using TTCal
using BPJSpec
using NLopt
using LsqFit
using FITSIO
using ProgressMeter

const workspace = joinpath(dirname(@__FILE__), "..", "..", "workspace")

function compare_with_guzman()
    fits = FITS(joinpath(workspace, "comparison-maps", "wlb45.fits"))
    img = read(fits[1])
    ϕ = linspace(0, 2π, size(img, 1)+1)[1:end-1]
    θ = linspace(0, π, size(img, 2))
    guzman = HealpixMap(Float64, 256)
    N = length(guzman)
    for pix = 1:N
        θ_, ϕ_ = LibHealpix.pix2ang_ring(nside(guzman), pix)
        ϕ_ = mod2pi(π - ϕ_)
        θ_ = π - θ_
        idx = searchsortedlast(ϕ, ϕ_)
        jdx = searchsortedlast(θ, θ_)
        guzman[pix] = img[idx, jdx]
    end

    mask = ones(Bool, N)
    frame = ReferenceFrame()
    sources = [Direction(dir"J2000", "19h59m28s", "+40d44m02s"), # Cyg A
               Direction(dir"J2000", "23h23m24s", "+58d48m54s"), # Cas A
               Direction(dir"J2000", "12h30m49s", "+12d23m28s"), # Vir A
               Direction(dir"J2000", "05h34m32s", "+22d00m52s")] # Tau A
    for pix = 1:length(guzman)
        θ, ϕ = LibHealpix.pix2ang_ring(nside(guzman), pix)
        galactic = Direction(dir"GALACTIC", ϕ*radians, (π/2-θ)*radians)
        j2000 = measure(frame, galactic, dir"J2000")
        ra = longitude(j2000)
        dec = latitude(j2000)
        if dec < deg2rad(-30)
            mask[pix] = false
        elseif dec > deg2rad(+65)
            mask[pix] = false
        end
        for source in sources
            if acosd(j2000.x*source.x + j2000.y*source.y + j2000.z*source.z) < 10
                mask[pix] = false
            end
        end
    end

    # Subtract sources from the Guzman maps
    function gaussian(x, y, A, σx, σy, θ)
        a = cos(θ)^2/(2σx^2) + sin(θ)^2/(2σy^2)
        b = -sin(2θ)/(4σx^2) + sin(2θ)/(4σy^2)
        c = sin(θ)^2/(2σx^2) + cos(θ)^2/(2σy^2)
        A*exp(-(a*x^2 + 2b*x*y + c*y^2))
    end
    function residual(map, disc, xlist, ylist, params)
        output = 0.0
        for (pixel, x, y) in zip(disc, xlist, ylist)
            g = gaussian(x, y, params[1], params[2], params[3], params[4])
            output += abs2(map[pixel] - g - params[5])
        end
        output
    end
    function remove(disc, xlist, ylist, params)
        for (pixel, x, y) in zip(disc, xlist, ylist)
            g = gaussian(x, y, params[1], params[2], params[3], params[4])
            guzman[pixel] -= g
        end
    end
    for source in sources
        direction = measure(frame, source, dir"GALACTIC")
        θ = π/2-latitude(direction)
        ϕ = longitude(direction)
        vec = LibHealpix.ang2vec(θ, ϕ)
        rhat = vec / norm(vec)
        north = [0, 0, 1]
        north = north - dot(rhat, north)*rhat
        north = north / norm(north)
        east = cross(north, rhat)
        disc = LibHealpix.query_disc(guzman, θ, ϕ, deg2rad(10), inclusive=true)
        x = Float64[]
        y = Float64[]
        for pix in disc
            myvec = LibHealpix.pix2vec_ring(nside(guzman), Int(pix))
            push!(x, asind(dot(myvec, east)))
            push!(y, asind(dot(myvec, north)))
        end

        opt = Opt(:LN_SBPLX, 5)
        ftol_rel!(opt, 1e-10)
        min_objective!(opt, (params, _)->residual(guzman, disc, x, y, params))
        println("starting")
        lower_bounds!(opt, [1, 1, 1, -π/2, 1])
        upper_bounds!(opt, [1e6, 10, 10, +π/2, 1e6])
        @time minf, params, ret = optimize(opt, [1, 5, 5, 0, 1])
        @show minf, params, ret
        remove(disc, x, y, params)
    end

    # Interpolate the LWA maps to 45 MHz
    spw = 6
    dir = Pipeline.Common.getdir(spw)
    ν6 = Pipeline.Common.getfreq(spw)
    lwa6 = readhealpix(joinpath(dir, "map-wiener-filtered-rainy-2048-galactic.fits"))

    spw = 8
    dir = Pipeline.Common.getdir(spw)
    ν8 = Pipeline.Common.getfreq(spw)
    lwa8 = readhealpix(joinpath(dir, "map-wiener-filtered-rainy-2048-galactic.fits"))

    ν = 45e6
    w6 = 1 - (ν - ν6)/(ν8 - ν6)
    w8 = 1 - w6

    lwa6 = lwa6 * (BPJSpec.Jy * (BPJSpec.c/ν)^2 / (2*BPJSpec.k))
    lwa8 = lwa8 * (BPJSpec.Jy * (BPJSpec.c/ν)^2 / (2*BPJSpec.k))
    lwa = w6*lwa6 + w8*lwa8
    @time lwa = smooth(lwa, 5, nside(guzman))

    # Filter the Guzman map in the same way the LWA map is filtered
    alm = map2alm(Pipeline.MModes.rotate_from_galactic(6, "rainy", guzman), 500, 500)
    @show alm[0, 0]
    Pipeline.MModes.apply_wiener_filter!(alm, 0:0)
    filtered_guzman = Pipeline.MModes.rotate_to_galactic(6, "rainy", alm2map(alm, nside(guzman)))

    lwa_pixels = [lwa.pixels[idx] for idx = 1:N if mask[idx]]
    guzman_pixels = [guzman.pixels[idx] for idx = 1:N if mask[idx]]
    monopole = mean(guzman_pixels)

    δ = HealpixMap(Float64, nside(guzman))
    for idx = 1:N
        if mask[idx]
            δ[idx] = (lwa[idx] - filtered_guzman[idx])/guzman[idx]
        end
    end

    save("comparison-with-guzman.jld",
         "guzman", guzman.pixels, "filtered_guzman", filtered_guzman.pixels,
         "lwa", lwa.pixels, "difference", δ.pixels)
end

function internal_comparison()
    filename = "map-restored-registered-rainy-itrf.fits"
    filename_odd  = "map-odd-restored-registered-rainy-itrf.fits"
    filename_even = "map-even-restored-registered-rainy-itrf.fits"

    trials = [(filename, filename, filename),
              (filename, filename, filename_odd ),
              (filename, filename, filename_even),
              (filename, filename_odd,  filename),
              (filename, filename_even, filename),
              (filename_odd, filename,  filename),
              (filename_even, filename, filename)]

    line_slope     = Vector{Float64}[]
    plane_slope_1  = Vector{Float64}[]
    plane_slope_2  = Vector{Float64}[]
    line_residual  = Vector{Float64}[]
    plane_residual = Vector{Float64}[]

    futures = [remotecall(fit_plane, idx+1, trials[idx]...) for idx = 1:length(trials)]
    for future in futures
        tmp = fetch(future)
        push!(line_slope,     tmp[1])
        push!(plane_slope_1,  tmp[2])
        push!(plane_slope_2,  tmp[3])
        push!(line_residual,  tmp[4])
        push!(plane_residual, tmp[5])
    end

    save("internal-spectral-index.jld",
         "line_slope", line_slope, "plane_slope_1", plane_slope_1, "plane_slope_2", plane_slope_2,
         "line_residual", line_residual, "plane_residual", plane_residual)
end

function fit_plane(filename1, filename2, filename3; width=5)
    println("Preparing 1...")
    ν1 = Pipeline.Common.getfreq(4)
    @time map1 = readhealpix(joinpath(Pipeline.Common.getdir(4), filename1))
    @time map1 = map1 * (BPJSpec.Jy * (BPJSpec.c/ν1)^2 / (2*BPJSpec.k))
    @time map1 = Pipeline.MModes.rotate_to_galactic(4, "rainy", map1)
    @time map1 = degrade(map1, 512)

    println("Preparing 2...")
    ν2 = Pipeline.Common.getfreq(10)
    @time map2 = readhealpix(joinpath(Pipeline.Common.getdir(10), filename2))
    @time map2 = map2 * (BPJSpec.Jy * (BPJSpec.c/ν2)^2 / (2*BPJSpec.k))
    @time map2 = Pipeline.MModes.rotate_to_galactic(4, "rainy", map2)
    @time map2 = degrade(map2, 512)

    println("Preparing 3...")
    ν3 = Pipeline.Common.getfreq(18)
    @time map3 = readhealpix(joinpath(Pipeline.Common.getdir(18), filename1))
    @time map3 = map3 * (BPJSpec.Jy * (BPJSpec.c/ν3)^2 / (2*BPJSpec.k))
    @time map2 = Pipeline.MModes.rotate_to_galactic(4, "rainy", map2)
    @time map3 = degrade(map3, 512)

    println("Fitting...")
    @time _fit_plane(map1, map2, map3, width)
end

function _fit_plane(map1, map2, map3, width)
    output_nside = 128
    output_npix  = nside2npix(output_nside)
    line_slope     = zeros(output_npix) # slope of a linear fit between map1 and map3
    plane_slope_1  = zeros(output_npix) # slope of a planar fit between map3 and map1
    plane_slope_2  = zeros(output_npix) # slope of a planar fit between map3 and map2
    line_residual  = zeros(output_npix) # residual for the linear fit
    plane_residual = zeros(output_npix) # residual for the planar fit

    meta = Pipeline.Common.getmeta(4, "rainy")
    frame = TTCal.reference_frame(meta)
    for idx = 1:output_npix
        θ, ϕ = LibHealpix.pix2ang_ring(output_nside, idx)
        galactic = Direction(dir"GALACTIC", (π/2-θ)*radians, ϕ*radians)
        itrf = measure(frame, galactic, dir"ITRF")
        dec = latitude(itrf) |> rad2deg
        dec < -30 && continue

        disc, weights = _disc_weights(map1, θ, ϕ, width)
        m, a, b, line_res, plane_res = _fit_plane(map1, map2, map3, disc, weights)
        line_slope[idx] = m
        plane_slope_1[idx] = a
        plane_slope_2[idx] = b
        line_residual[idx] = line_res
        plane_residual[idx] = plane_res
    end
    line_slope, plane_slope_1, plane_slope_2, line_residual, plane_residual
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
    weights = (cos(π*distance/width)+1)/2
    disc, weights
end

using PyPlot

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

    #figure(1); clf()
    #scatter(x, y, c=z, s=weights, vmin=minimum(z), vmax=maximum(z))
    #colorbar()
    #xlim(minimum(x), maximum(x))
    #ylim(minimum(y), maximum(y))
    #@show m_line m_plane
    #@show residual_line residual_plane

    m_line[1], m_plane[1], m_plane[2], residual_line, residual_plane
end

#function compare_with_haslam()
#    haslam = readhealpix(joinpath(workspace, "comparison-maps", "haslam408_dsds_Remazeilles2014.fits"))
#    haslam_freq = 408e6
#
#    # There's a type instability in here somewhere because loading from disk makes the power law
#    # fitting code way faster.
#
#    #lwa = HealpixMap[]
#    #for spw = 4:2:18
#    #    @show spw
#    #    ν = Pipeline.Common.getfreq(spw)
#    #    dir = Pipeline.Common.getdir(spw)
#    #    map = readhealpix(joinpath(dir, "map-wiener-filtered-rainy-2048-galactic.fits"))
#    #    map = smooth(map, 56/60, nside(haslam))
#    #    map = map * (BPJSpec.Jy * (BPJSpec.c/ν)^2 / (2*BPJSpec.k))
#    #    push!(lwa, map)
#    #    writehealpix("tmp/$spw.fits", map, replace=true)
#    #end
#    lwa = HealpixMap[readhealpix("tmp/$spw.fits") for spw = 4:2:18]
#    lwa_freq = Float64[Pipeline.Common.getfreq(spw) for spw = 4:2:18]
#
#    # Fit a power law to each pixel
#    ν = [lwa_freq; haslam_freq]
#    maps = [lwa; haslam]
#
#    N = length(haslam)
#    flags = zeros(Bool, N)
#    spectral_index = zeros(N)
#
#    A = [log10(ν/70e6) ones(length(ν))]
#    prg = Progress(N)
#    for pixel = 1:N
#        y = [map[pixel] for map in maps]
#        keep = y .> 0
#        if sum(keep) ≥ 2
#            line = A[keep, :]\log10(y[keep])
#            spectral_index[pixel] = line[1]
#        else
#            flags[pixel] = true
#        end
#        next!(prg)
#    end
#
#    index_map = HealpixMap(spectral_index)
#    img = mollweide(index_map)
#
#    #figure(1); clf()
#    #writehealpix("index_map.fits", index_map, replace=true)
#    #index_map = readhealpix("index_map.fits")
#    #imshow(mollweide(index_map), vmin=-2.8, vmax=-2.2, cmap=get_cmap("RdBu"))
#    #colorbar()
#
#    save(joinpath("../workspace/comparison-with-haslam.jld"), "index", img)
#end

function smooth(map, width, output_nside=nside(map))
    # spherical convolution: https://www.cs.jhu.edu/~misha/Spring15/17.pdf
    σ = width/(2sqrt(2log(2)))
    kernel = HealpixMap(Float64, output_nside)
    for pix = 1:length(kernel)
        θ, ϕ = LibHealpix.pix2ang_ring(nside(kernel), pix)
        θ = rad2deg(θ)
        kernel[pix] = exp(-θ^2/(2σ^2))
    end
    dΩ = 4π/length(kernel)
    kernel = HealpixMap(kernel.pixels / (sum(kernel.pixels)*dΩ))

    lmax = mmax = 1000
    map_alm = map2alm(map, lmax, mmax, iterations=10)
    kernel_alm = map2alm(kernel, lmax, mmax, iterations=10)
    output_alm = Alm(Complex128, lmax, mmax)
    for m = 0:mmax, l = m:lmax
        output_alm[l, m] = sqrt((4π)/(2l+1))*map_alm[l, m]*kernel_alm[l, 0]
    end

    alm2map(output_alm, output_nside)
end

"degrade the map to a lower nside so that adjacent pixels aren't correlated anymore"
function degrade(map, new_nside)
    new_npix = nside2npix(new_nside)
    output = zeros(new_npix)
    normalization = zeros(Int, new_npix)
    for idx = 1:length(map)
        vec = LibHealpix.pix2vec_ring(nside(map), idx)
        jdx = LibHealpix.vec2pix_ring(new_nside, vec)
        output[jdx] += map[idx]
        normalization[jdx] += 1
    end
    HealpixMap(output ./ normalization)
end

end

