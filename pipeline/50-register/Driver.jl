module Driver

using CasaCore.Measures
using FileIO, JLD2
using LibHealpix
using ProgressMeter
using StaticArrays
using TTCal
using Unitful

#using PyPlot # temp

include("../lib/Common.jl"); using .Common

function register(spw, name)
    path = getdir(spw, name)
    map = readhealpix(joinpath(path, "clean-map.fits"))

    ra, dec, flux = read_vlssr_catalog()
    ra, dec, flux = flux_cutoff(ra, dec, flux, 30)
    ra, dec, flux = near_bright_source_filter(ra, dec, flux)
    ra, dec, flux = too_close_together(ra, dec, flux)
    N = length(flux)

    metadata = load(joinpath(getdir(spw, name), "raw-visibilities.jld2"), "metadata")
    TTCal.slice!(metadata, 1, axis=:time)
    frame = ReferenceFrame(metadata)

    catalog   = convert_to_itrf(frame, ra, dec)
    measured  = register_centroid(map, catalog)
    rotations = [Measures.RotationMatrix(catalog[idx], measured[idx]) for idx = 1:N]

    @time dedistorted = dedistort(map, catalog, rotations)
    writehealpix(joinpath(path, "clean-map-registered.fits"), dedistorted, replace=true)

    map = readhealpix(joinpath(path, "clean-map-residuals.fits"))
    @time dedistorted = dedistort(map, catalog, rotations)
    writehealpix(joinpath(path, "clean-map-registered-residuals.fits"), dedistorted, replace=true)

    #function line(start, finish)
    #    scale = 50
    #    x = ustrip.([longitude(start), longitude(finish)])
    #    y = ustrip.([ latitude(start),  latitude(finish)])
    #    if x[2] - x[1] > π
    #        x[2] -= 2π
    #    elseif x[1] - x[2] > π
    #        x[2] += 2π
    #    end
    #    x[2] = x[1] + scale*(x[2]-x[1])
    #    y[2] = y[1] + scale*(y[2]-y[1])
    #    x, y
    #end

    #figure(1); clf()
    #for idx = 1:N
    #    x, y = line(catalog[idx], measured[idx])
    #    plot(x, y, "r-", lw=1)
    #    plot(x[2], y[2], "r.")
    #end
    #for l in linspace(-π, π, 40)[1:end-1], b in linspace(-π/2, π/2, 20)[2:end-1]
    #    start    = Direction(dir"ITRF", l*u"rad", b*u"rad")
    #    rotation = interpolate_rotation(catalog, rotations, start)
    #    finish   = rotation*start
    #    x, y = line(start, finish)
    #    plot(x, y, "k-", lw=1)
    #    plot(x[2], y[2], "k.")
    #end
end

function read_vlssr_catalog()
    path = joinpath(dirname(@__FILE__), "..", "..", "workspace", "catalogs", "vlssr.dat")
    data = readdlm(path, skipstart=2)
    ra_hours    = data[:, 1]
    ra_minutes  = data[:, 2]
    ra_seconds  = data[:, 3]
    dec_degrees = data[:, 4]
    dec_minutes = data[:, 5]
    dec_seconds = data[:, 6]
    flux = data[:, 7]

    ra  = @. deg2rad(15*(ra_hours + (ra_minutes + ra_seconds/60)/60))
    dec = @. sign(dec_degrees) * deg2rad(abs(dec_degrees) + (dec_minutes + dec_seconds/60)/60)

    ra, dec, flux
end

function flux_cutoff(ra, dec, flux, cutoff)
    # Select only bright sources
    select = flux .> cutoff
    ra   = ra[select]
    dec  = dec[select]
    flux = flux[select]
    ra, dec, flux
end

function near_bright_source_filter(ra, dec, flux)
    # Discard sources near bright sources
    function distance_to(ra, dec, ra_str, dec_str)
        _ra  = sexagesimal(ra_str)
        _dec = sexagesimal(dec_str)
        x1 = @. cos(ra) * cos(dec)
        y1 = @. sin(ra) * cos(dec)
        z1 = @. sin(dec)
        x2 = cos(_ra) * cos(_dec)
        y2 = sin(_ra) * cos(_dec)
        z2 = sin(_dec)
        @. acosd(x1*x2 + y1*y2 + z1*z2)
    end

    sources = [("19h59m28.35663s", "+40d44m02.0970s"), # Cyg A
               ("23h23m24s", "58d48m54s"), # Cas A
               ("12h30m49.42338s", "+12d23m28.0439s"), # Vir A
               ("05h34m31.94s", "+22d00m52.2s"), # Tau A
               ("16h51m11.4s", "+04d59m20s"), # Her A
               ("09h18m05.651s", "-12d05m43.99s"), # Hya A
               ("04h37m04.3753s", "+29d40m13.819s"), # Per B
               ("17h20m28.147s", "-00d58m47.12s")] # 3C 353

    for source in sources
        distance = distance_to(ra, dec, source...)
        select = distance .> 1
        ra   = ra[select]
        dec  = dec[select]
        flux = flux[select]
    end

    ra, dec, flux
end

function too_close_together(ra, dec, flux)
    # Discard sources that are too close to other sources
    function distance_to(ra1, dec1, ra2, dec2)
        x1 = cos(ra1) .* cos(dec1)
        y1 = sin(ra1) .* cos(dec1)
        z1 = sin(dec1)
        x2 = cos(ra2) * cos(dec2)
        y2 = sin(ra2) * cos(dec2)
        z2 = sin(dec2)
        acosd(x1*x2 + y1*y2 + z1*z2)
    end

    @label start
    N = length(flux)
    for idx = 1:N, jdx = idx+1:N
        if distance_to(ra[idx], dec[idx], ra[jdx], dec[jdx]) < 1
            if flux[idx] > flux[jdx]
                deleteat!(ra, jdx)
                deleteat!(dec, jdx)
                deleteat!(flux, jdx)
                @goto start
            else
                deleteat!(ra, idx)
                deleteat!(dec, idx)
                deleteat!(flux, idx)
                @goto start
            end
        end
    end

    ra, dec, flux
end

function output_region_file(ra, dec)
    ds9_region_file = open("vlssr.reg", "w")
    println(ds9_region_file, "global color=red edit=0 move=0 delete=1")
    println(ds9_region_file, "fk5")
    function write_out(ra, dec)
        ra_str  = sexagesimal( ra, digits=2, hours=true)
        dec_str = sexagesimal(dec, digits=1)
        println(ds9_region_file, @sprintf("circle(%s,%s,%d\")", ra_str, dec_str, 10000))
    end

    N = length(ra)
    for idx = 1:N
        write_out(ra[idx], dec[idx])
    end

    close(ds9_region_file)
end

function convert_to_itrf(frame, ra, dec)
    output = Direction[]
    for idx = 1:length(ra)
        j2000 = Direction(dir"J2000", ra[idx]*u"rad", dec[idx]*u"rad")
        itrf  = measure(frame, j2000, dir"ITRF")
        push!(output, itrf)
    end
    output
end

function register_centroid(map, directions)
    idx = 1
    N = length(directions)
    prg = Progress(N)
    centroids = Direction[]
    for direction in directions
        push!(centroids, _register_centroid(map, direction))
        next!(prg)
    end
    centroids
end

function _register_centroid(map, direction)
    θ = ustrip(π/2 - latitude(direction))
    ϕ = ustrip(longitude(direction))
    disc  = query_disc(map, θ, ϕ, deg2rad(0.5), inclusive=true)
    pixel = disc[indmax(map[disc])]
    vec = pix2vec(map, pixel)
    Direction(dir"ITRF", vec[1], vec[2], vec[3])
end

function interpolate_rotation(catalog, rotations, direction)
    product   = dot.(direction, catalog)
    selection = sortperm(product, rev=true)[1:5]
    weights   = 1 ./ (acosd.(product[selection]).+1) # 1 / (θ + 1°)
    matrix    = @SMatrix zeros(3, 3)
    for (s, w) in zip(selection, weights)
        matrix += rotations[s].matrix * w
    end
    matrix /= sum(weights)
    Measures.RotationMatrix(rotations[1].sys, matrix)
end

function dedistort(map, catalog, rotations)
    Npixels  = length(map)
    Nworkers = length(workers())
    chunks = [idx:Nworkers:Npixels for idx = 1:Nworkers]

    dedistorted = RingHealpixMap(Float64, map.nside)
    @sync for worker in workers()
        @async begin
            pixels = pop!(chunks)
            output = remotecall_fetch(_dedistort, worker, map, pixels, catalog, rotations)
            for (idx, pixel) in enumerate(pixels)
                dedistorted[pixel] = output[idx]
            end
        end
    end
    dedistorted
end

function _dedistort(map, pixels::AbstractVector, catalog, rotations)
    output = zeros(length(pixels))
    for (idx, pixel) in enumerate(pixels)
        output[idx] = _dedistort(map, pixel, catalog, rotations)
    end
    output
end

function _dedistort(map, pixel::Integer, catalog, rotations)
    vec = pix2vec(map, pixel)
    dir = Direction(catalog[1].sys, vec[1], vec[2], vec[3])
    rotation = interpolate_rotation(catalog, rotations, dir)
    dir = rotation*dir
    θ = ustrip(π/2 - latitude(dir))
    ϕ = ustrip(longitude(dir))
    LibHealpix.interpolate(map, θ, ϕ)::Float64
end

end

