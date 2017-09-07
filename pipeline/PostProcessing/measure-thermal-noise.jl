function measure_thermal_noise(dataset)
    for spw = 4:2:18
        measure_thermal_noise(spw, dataset)
    end
end

function measure_thermal_noise(spw, dataset)
    dir = getdir(spw)
    everything = load(joinpath(dir, "map-restored-registered-rainy.jld"), "map")
    odd  = load(joinpath(dir, "map-odd-restored-registered-rainy.jld"),  "map")
    even = load(joinpath(dir, "map-even-restored-registered-rainy.jld"), "map")

    npix = length(everything)
    nside = npix2nside(npix)
    mask = zeros(Bool, npix)
    for pix = 1:length(everything)
        θ, ϕ = LibHealpix.pix2ang_ring(nside, pix)
        dec = rad2deg(π/2-θ)
        mask[pix] = dec > -30
    end

    everything = everything[mask]
    odd  =  odd[mask]
    even = even[mask]

    ν = getfreq(spw)
    scale = (BPJSpec.Jy * (BPJSpec.c/ν)^2 / (2*BPJSpec.k))
    per_pixel_variance = 0.5*(abs2.(odd-everything) + abs2.(even-everything))
    stddev = sqrt(mean(per_pixel_variance))

    stddev_K  = stddev*scale
    stddev_Jy = convert_to_janskys(spw, dataset, stddev)

    @show spw, stddev_K, stddev_Jy
end

function convert_to_janskys(spw, dataset, stddev)
    dir = joinpath(getdir(spw), "psf")
    psf = load(joinpath(dir, "psf.jld"), "psf")
    major_σ, minor_σ, angle = load(joinpath(dir, "gaussian.jld"), "major", "minor", "angle")

    pixels = psf.pixels
    dec = [rad2deg(π/2 - LibHealpix.pix2ang_ring(psf.nside, pixel)[1]) for pixel in pixels]

    idx = searchsortedlast(dec, +45, rev=true)
    σx = deg2rad(major_σ[idx]/60)
    σy = deg2rad(minor_σ[idx]/60)
    θ = deg2rad(angle[idx])

    solid_angle = 2π*σx*σy

    ν = getfreq(spw)
    stddev*solid_angle
end

