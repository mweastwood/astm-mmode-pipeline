# Generate data needed for making plots in the paper.
module Plots

using Pipeline
using PyPlot
using JLD
using LibHealpix
using CasaCore.Measures
using NLopt

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





end

