module Driver

using CasaCore.Measures
using FileIO, HDF5, JLD2
using LibHealpix
using ProgressMeter
using TTCal

include("../lib/Common.jl");   using .Common
include("../lib/Cleaning.jl"); using .Cleaning

function psf(spw, name)
    local lmax, mmax
    path = getdir(spw, name)
    jldopen(joinpath(path, "observation-matrix.jld2"), "r") do file
        lmax = file["lmax"]
        mmax = file["mmax"]
    end
    nside = 2048
    pixels, peak, major, minor, angle = compute(path, lmax, mmax, nside)
    jldopen(joinpath(path, "psf-properties.jld2"), "w") do file
        file["lmax"]   = lmax
        file["mmax"]   = mmax
        file["nside"]  = nside
        file["pixels"] = pixels
        file["peak"]   = peak
        file["major"]  = major
        file["minor"]  = minor
        file["angle"]  = angle
    end
end

function psf_images(spw, name)
    local lmax, mmax
    path = getdir(spw, name)
    jldopen(joinpath(path, "observation-matrix.jld2"), "r") do file
        lmax = file["lmax"]
        mmax = file["mmax"]
    end
    nside = 2048
    images, ra, dec, central_ra, central_dec = compute_images(path, lmax, mmax, nside)
    h5open(joinpath(path, "psf-images.h5"), "w") do file
        file["images"] = images
        file["ra"]     = ra
        file["dec"]    = dec
        file["central_ra"]  = central_ra
        file["central_dec"] = central_dec
    end
end

function compute(path, lmax, mmax, nside)
    pixels = find_healpix_rings(nside)
    responsibilities = distribute_responsibilities(mmax)
    @time load_observation_matrix(joinpath(path, "observation-matrix.jld2"), responsibilities)

    N = length(pixels)
    peak  = zeros(N)
    major = zeros(N)
    minor = zeros(N)
    angle = zeros(N)

    prg = Progress(N)
    for idx = 1:N
        pixel = pixels[idx]
        θ, ϕ = LibHealpix.pix2ang_ring(nside, pixel)
        alm = psf_alm(θ, ϕ, lmax, mmax, responsibilities)
        map = alm2map(alm, nside)
        peak[idx], major[idx], minor[idx], angle[idx] = psf_properties(map, pixel)
        next!(prg)
    end

    pixels, peak, major, minor, angle
end

"""
Instead of computing the PSF properties, this function extracts postage stamp images of the PSF at a
handful of rings.
"""
function compute_images(path, lmax, mmax, nside)
    pixels = find_healpix_rings(nside)
    responsibilities = distribute_responsibilities(mmax)
    @time load_observation_matrix(joinpath(path, "observation-matrix.jld2"), responsibilities)

    metadata = load(joinpath(path, "raw-visibilities.jld2"), "metadata")
    TTCal.slice!(metadata, 1, axis=:time)
    frame = ReferenceFrame(metadata)

    pixels = pixels[1:10:end]
    N = length(pixels)
    M = 401
    images = zeros(M, M, N)
    ra     = zeros(M, M, N) # J2000 RA
    dec    = zeros(M, M, N) # J2000 dec
    central_ra  = zeros(N)  # J2000 RA of the central pixel
    central_dec = zeros(N)  # J2000 dec of the central pixel
    central_pix = round(Int, middle(1:M))

    prg = Progress(N)
    for idx = 1:N
        pixel = pixels[idx]
        θ, ϕ = LibHealpix.pix2ang_ring(nside, pixel)
        alm = psf_alm(θ, ϕ, lmax, mmax, responsibilities)
        map = alm2map(alm, nside)
        img, vecs = Cleaning.postage_stamp_with_unit_vectors(map, pixel, extent=5, N=M)
        output_images!(images, ra, dec, central_ra, central_dec, central_pix,
                       img, vecs, frame, idx, M)
        next!(prg)
    end

    images, ra, dec, central_ra, central_dec
end

function output_images!(images, ra, dec, central_ra, central_dec, central_pix,
                        img, vecs, frame, idx, M)
    x  = Direction(dir"J2000", 1, 0, 0)
    y  = Direction(dir"J2000", 0, 1, 0)
    z  = Direction(dir"J2000", 0, 0, 1)
    x′ = measure(frame, x, dir"ITRF")
    y′ = measure(frame, y, dir"ITRF")
    z′ = measure(frame, z, dir"ITRF")

    for jdx = 1:M, kdx = 1:M
        images[kdx, jdx, idx] = img[kdx, jdx]
        itrf  = Direction(dir"ITRF", vecs[1, kdx, jdx], vecs[2, kdx, jdx], vecs[3, kdx, jdx])
        ra[kdx, jdx, idx] = atan2(dot(itrf, y′), dot(itrf, x′))
        dec[kdx, jdx, idx] = asin(dot(itrf, z′))
    end
    central_dec[idx]    =    dec[central_pix, central_pix, idx]
    central_ra[idx]     =     ra[central_pix, central_pix, idx]
    images[:, :, idx] ./= images[central_pix, central_pix, idx]
end

function psf_alm(θ, ϕ, lmax, mmax, responsibilities)
    alm = pointsource_alm(θ, ϕ, lmax, mmax)
    observe!(alm, responsibilities)
    alm
end

function psf_properties(map, pixel; extent=1)
    vec = LibHealpix.pix2vec_ring(map.nside, pixel)
    img = postage_stamp(map, pixel; extent=extent)

    # Compute the peak value of the PSF
    peak = map[pixel]
    img ./= peak

    # Compute the major and minor axes
    xgrid = linspace(-deg2rad(extent), +deg2rad(extent), 1001)
    ygrid = linspace(-deg2rad(extent), +deg2rad(extent), 1001)
    keep_y, keep_x = findn(img .> 0.5)
    count = length(keep_x)
    x = xgrid[keep_x]
    y = ygrid[keep_y]
    A = [x y]
    U, S, V = svd(A)
    major_axis = V[:, 1]
    minor_axis = V[:, 2]
    major_scale = S[1]
    minor_scale = S[2]

    # Compute the FWHM by assuming all pixels > 0.5 fill an elliptical aperture
    dΩ = ((2extent)^2 / (180/π)^2) / (length(xgrid)*length(ygrid))
    Ω = count * dΩ

    C = sqrt(Ω/(π*major_scale*minor_scale))
    major_hwhm = C*major_scale
    minor_hwhm = C*minor_scale
    major_fwhm = 2major_hwhm
    minor_fwhm = 2minor_hwhm
    major_σ = major_fwhm/(2sqrt(2log(2)))
    minor_σ = minor_fwhm/(2sqrt(2log(2)))
    angle = atan2(major_axis[1], major_axis[2])

    major_σ = 60rad2deg(major_σ)
    minor_σ = 60rad2deg(minor_σ)
    angle = rad2deg(angle)

    peak, major_σ, minor_σ, angle
end

"Starting pixel of each Healpix ring."
function find_healpix_rings(nside)
    nring  = nside2nring(nside)
    pixels = [LibHealpix.ring_info2(nside, ring)[1] for ring = 1:nring]
    # discard pixels below -30 dec
    filter!(pixels) do pixel
        θ, ϕ = LibHealpix.pix2ang_ring(nside, pixel)
        θ < deg2rad(120)
    end
end

end

