# Generate data needed for making plots in the paper.
module Plots

using Pipeline
using PyPlot
using JLD
using LibHealpix
using CasaCore.Measures
using NLopt
using FITSIO
using BPJSpec
using ProgressMeter

"Create an image of the psf."
function psf_image()
    spw = 4
    str = @sprintf("spw%02d", spw)
    dataset = "rainy"
    dir = Pipeline.Common.getdir(spw)
    observation_matrix, lmax, mmax = load(joinpath(dir, "observation-matrix-$dataset.jld"),
                                          "blocks", "lmax", "mmax")
    nside = 2048

    direction = Direction(dir"ITRF", 0degrees, 45degrees)
    θ = π/2 - latitude(direction)
    ϕ = longitude(direction)
    alm = Pipeline.Cleaning.getpsf_alm(observation_matrix, θ, ϕ, lmax, mmax)
    map = alm2map(alm, nside)
    img = Pipeline.Cleaning.postage_stamp(map, direction)
    save(joinpath(dir, "tmp", "$str-psf-45-degrees.jld"), "img", img)

    direction = Direction(dir"ITRF", 0degrees, 0degrees)
    θ = π/2 - latitude(direction)
    ϕ = longitude(direction)
    alm = Pipeline.Cleaning.getpsf_alm(observation_matrix, θ, ϕ, lmax, mmax)
    map = alm2map(alm, nside)
    img = Pipeline.Cleaning.postage_stamp(map, direction)
    save(joinpath(dir, "tmp", "$str-psf-00-degrees.jld"), "img", img)
end

"Measure the width of the PSF."
function psf_width()
    dataset = "rainy"

    xgrid = linspace(-deg2rad(0.5), +deg2rad(0.5), 101)
    ygrid = linspace(-deg2rad(0.5), +deg2rad(0.5), 101)
    function gaussian(x, y, A, σx, σy, θ)
        a = cos(θ)^2/(2σx^2) + sin(θ)^2/(2σy^2)
        b = -sin(2θ)/(4σx^2) + sin(2θ)^2/(4σy^2)
        c = sin(θ)^2/(2σx^2) + cos(θ)^2/(2σy^2)
        A*exp(-(a*x^2 + 2b*x*y + c*y^2))
    end
    function residual(image, params, grad)
        output = 0.0
        for (jdx, y) in enumerate(ygrid), (idx, x) in enumerate(xgrid)
            g = gaussian(x, y, params[1], params[2], params[3], params[4])
            output += abs2(image[idx, jdx] - g)
        end
        output
    end

    for spw = 4:2:18
        dir = Pipeline.Common.getdir(spw)
        @time observation_matrix, lmax, mmax = load(joinpath(dir, "observation-matrix-$dataset.jld"),
                                                   "blocks", "lmax", "mmax")
        nside = 2048

        direction = Direction(dir"ITRF", 0degrees, 45degrees)
        θ = π/2 - latitude(direction)
        ϕ = longitude(direction)
        alm = Pipeline.Cleaning.getpsf_alm(observation_matrix, θ, ϕ, lmax, mmax)
        map = alm2map(alm, nside)
        img = Pipeline.Cleaning.postage_stamp(map, xgrid, ygrid, direction)

        opt = Opt(:LN_SBPLX, 4)
        ftol_rel!(opt, 1e-10)
        min_objective!(opt, (x, g)->residual(img, x, g))
        println("starting")
        lower_bounds!(opt, [1, 0, 0, -π/2])
        upper_bounds!(opt, [1e6, π/180, π/180, +π/2])
        @time minf, params, ret = optimize(opt, [1, deg2rad(10/60), deg2rad(10/60), 0])
        @show minf, params, ret
        σx = params[2]
        σy = params[3]
        σ = (σx + σy)/2
        σ = 60rad2deg(σ)
        fwhm = 2sqrt(2log(2))*σ
        @show spw, fwhm

        #fit = [gaussian(x, y, params...) for x in xgrid, y in ygrid]

        #figure(1); clf()
        #imshow(img)
        #gca()[:set_aspect]("equal")
        #colorbar()

        #figure(2); clf()
        #imshow(fit, vmin=minimum(img), vmax=maximum(img))
        #gca()[:set_aspect]("equal")
        #colorbar()

        #figure(3); clf()
        #imshow(img-fit)
        #gca()[:set_aspect]("equal")
        #colorbar()
    end
end

function compare_with_guzman()
    fits = FITS("../workspace/comparison-maps/wlb45.fits")
    # TODO is this in B1950 coordinates????
    img = read(fits[1])
    ϕ = linspace(0, 2π, size(img, 1)+1)[1:end-1]
    θ = linspace(0, π, size(img, 2))
    guzman = HealpixMap(Float64, 256)
    for pix = 1:length(guzman)
        θ_, ϕ_ = LibHealpix.pix2ang_ring(nside(guzman), pix)
        ϕ_ = mod2pi(π - ϕ_)
        θ_ = π - θ_
        idx = searchsortedlast(ϕ, ϕ_)
        jdx = searchsortedlast(θ, θ_)
        guzman[pix] = img[idx, jdx]
    end

    spw = 8
    dir = Pipeline.Common.getdir(spw)
    @time lwa = readhealpix(joinpath(dir, "map-wiener-filtered-rainy-2048-galactic.fits"))
    meta = Pipeline.Common.getmeta(spw, "rainy")
    ν = meta.channels[55]
    @time lwa = lwa * (BPJSpec.Jy * (BPJSpec.c/ν)^2 / (2*BPJSpec.k))
    @time lwa = smooth(lwa, 5, nside(guzman))

    img1 = mollweide(guzman)
    img2 = mollweide(lwa)

    figure(1); clf()
    subplot(211)
    imshow(img1, vmin=4000, vmax=13000)
    colorbar()
    subplot(212)
    imshow((img2-img1)./img1, vmin=-0.5, vmax=+0.5, cmap=get_cmap("RdBu_r"))
    colorbar()
    tight_layout()

    save(joinpath(dir, "tmp", "comparison-with-guzman.jld"), "guzman", img1, "lwa", img2)
end

function compare_with_haslam()
    haslam = readhealpix("../workspace/comparison-maps/haslam408_dsds_Remazeilles2014.fits")
    haslam_freq = 408e6

    # There's a type instability in here somewhere because loading from disk makes the power law
    # fitting code way faster.

    #lwa = HealpixMap[]
    #for spw = 4:2:18
    #    @show spw
    #    ν = Pipeline.Common.getfreq(spw)
    #    dir = Pipeline.Common.getdir(spw)
    #    map = readhealpix(joinpath(dir, "map-wiener-filtered-rainy-2048-galactic.fits"))
    #    map = smooth(map, 56/60, nside(haslam))
    #    map = map * (BPJSpec.Jy * (BPJSpec.c/ν)^2 / (2*BPJSpec.k))
    #    push!(lwa, map)
    #    writehealpix("tmp/$spw.fits", map, replace=true)
    #end
    lwa = HealpixMap[readhealpix("tmp/$spw.fits") for spw = 4:2:18]
    lwa_freq = Float64[Pipeline.Common.getfreq(spw) for spw = 4:2:18]

    # Fit a power law to each pixel
    ν = [lwa_freq; haslam_freq]
    maps = [lwa; haslam]

    N = length(haslam)
    flags = zeros(Bool, N)
    spectral_index = zeros(N)

    A = [log10(ν/70e6) ones(length(ν))]
    prg = Progress(N)
    for pixel = 1:N
        y = [map[pixel] for map in maps]
        keep = y .> 0
        if sum(keep) ≥ 2
            line = A[keep, :]\log10(y[keep])
            spectral_index[pixel] = line[1]
        else
            flags[pixel] = true
        end
        next!(prg)
    end

    index_map = HealpixMap(spectral_index)
    img = mollweide(index_map)

    #figure(1); clf()
    #writehealpix("index_map.fits", index_map, replace=true)
    #index_map = readhealpix("index_map.fits")
    #imshow(mollweide(index_map), vmin=-2.8, vmax=-2.2, cmap=get_cmap("RdBu"))
    #colorbar()

    save(joinpath("../workspace/comparison-with-haslam.jld"), "index", img)
end

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

end

