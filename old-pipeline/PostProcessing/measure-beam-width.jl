function measure_beam_width(dataset)
    for spw = 4:2:18
        measure_beam_width(spw, dataset)
    end
end

function measure_beam_width(spw, dataset)
    dir = joinpath(getdir(spw), "psf")
    psf = load(joinpath(dir, "psf.jld"), "psf")
    major_σ, minor_σ, angle = load(joinpath(dir, "gaussian.jld"), "major", "minor", "angle")

    pixels = psf.pixels
    dec = [rad2deg(π/2 - LibHealpix.pix2ang_ring(psf.nside, pixel)[1]) for pixel in pixels]

    idx = searchsortedlast(dec, +45, rev=true)
    a = major_σ[idx]
    b = minor_σ[idx]

    fwhm_scale = 2sqrt(2log(2))
    fwhm_major = a * fwhm_scale
    fwhm_minor = b * fwhm_scale
    fwhm_total = sqrt(a*b) * fwhm_scale

    @show spw, fwhm_total, fwhm_major, fwhm_minor
end

