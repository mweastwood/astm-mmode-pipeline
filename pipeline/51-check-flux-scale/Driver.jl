module Driver

using CasaCore.Measures
using FileIO, JLD2
using LibHealpix
using StaticArrays
using TTCal
using Unitful, UnitfulAstro

include("../lib/Common.jl");   using .Common
include("../lib/Cleaning.jl"); using .Cleaning

function check_flux_scale(spw, name)
    path = getdir(spw, name)

    local pixels, peak, major, minor, angle
    jldopen(joinpath(path, "psf-properties.jld2"), "r") do file
        pixels = file["pixels"]
        peak   = file["peak"]
        major  = file["major"]
        minor  = file["minor"]
        angle  = file["angle"]
    end

    scaife = scaife_flux_calibrators()
    perley = perley_flux_calibrators()
    map = readhealpix(joinpath(path, "clean-map-registered.fits"))
    metadata = load(joinpath(path, "raw-visibilities.jld2"), "metadata")

    # Ah, it seems that I've made a mistake when folding the data in sidereal time. There I simply
    # added the xx and yy visibilities ($xx+yy$ instead of $(xx+yy)/2$). This mistake means that
    # every pixel in the map is overestimated by a factor of 2. We will make thie correction here to
    # avoid needing to redo imaging and cleaning.
    map ./= 2

    # We will now check the flux of several flux calibrators against their measured flux in the map.
    # In the future we may want to use this information to reset the flux scale again, but for now
    # it's just a consistency check.

    TTCal.slice!(metadata, 1, axis=:time)
    frame = ReferenceFrame(metadata)
    ν = metadata.frequencies[(Nfreq(metadata)+1)÷2]

    println("Scaife")
    for source in keys(scaife)
        spectrum  = scaife[source]
        direction = measure(frame, source_direction[source], dir"ITRF")
        model     = spectrum(ν).I
        measured  = measure_flux(map, direction, pixels, peak, major, minor, angle)
        @show source, model, measured, measured/model
    end

    println("Perley")
    for source in keys(perley)
        spectrum  = perley[source]
        direction = measure(frame, source_direction[source], dir"ITRF")
        model     = spectrum(ν).I
        measured  = measure_flux(map, direction, pixels, peak, major, minor, angle)
        @show source, model, measured, measured/model
    end

    # Now we will put the map in units of Kelvin, because there is a God and he wills it.
    factor = ustrip(uconvert(u"K", u"Jy * c^2/(2*k)"/ν^2))
    map  .*= factor

    writehealpix(joinpath(path, "clean-map-kelvin.fits"), map, replace=true)

    pixels, peak
end

function measure_flux(map, direction, pixels, peak, major, minor, angle)
    θ = π/2 - ustrip(latitude(direction))
    ϕ = ustrip(longitude(direction))
    disc = query_disc(map, θ, ϕ, deg2rad(10/60), inclusive=true)
    annulus = setdiff(query_disc(map, θ, ϕ, deg2rad(3), inclusive=true),
                      query_disc(map, θ, ϕ, deg2rad(1), inclusive=true))

    vec = ang2vec(θ, ϕ)
    north  = SVector(0, 0, 1)
    north -= dot(north, vec)*vec
    north /= norm(north)
    east = cross(north, vec)

    numerator   = 0.0
    denominator = 0.0
    for pixel in disc
        vec  = pix2vec(map, pixel)

        ring = searchsortedlast(pixels, pixel)
        x = asind(dot(vec, east)) * 60
        y = asind(dot(vec, north)) * 60
        value = gaussian(x, y, peak[ring], major[ring], minor[ring], deg2rad(angle[ring]))

        numerator   += map[pixel]
        denominator += value
    end
    #numerator   = maximum([map[pixel] for pixel in disc])
    #denominator = peak[searchsortedlast(pixels, ang2pix(map, θ, ϕ))]
    background  = median([map[pixel] for pixel in annulus])

    (numerator - background) / denominator
end

macro perley_spectrum(args...)
    flux = 10^args[1]
    coeff = [args[2:end]...]
    quote
        TTCal.PowerLaw($flux, 0, 0, 0, 1e9u"Hz", $coeff)
    end
end

macro scaife_spectrum(args...)
    flux = args[1]
    coeff = [args[2:end]...]
    quote
        TTCal.PowerLaw($flux, 0, 0, 0, 150e6u"Hz", $coeff)
    end
end

macro baars_spectrum(args...)
    flux = 10^args[1]
    coeff = [args[2:end]...]
    quote
        TTCal.PowerLaw($flux, 0, 0, 0, 1e6u"Hz", $coeff)
    end
end

function perley_flux_calibrators()
    spectra = Dict("3C 48"  => @perley_spectrum(1.3253, -0.7553, -0.1914, +0.0498),
                   "Per B"  => @perley_spectrum(1.8017, -0.7884, -0.1035, -0.0248, +0.0090),
                   "3C 147" => @perley_spectrum(1.4516, -0.6961, -0.2007, +0.0640, -0.0464, +0.0289),
                   "Lyn A"  => @perley_spectrum(1.2872, -0.8530, -0.1534, -0.0200, +0.0201),
                   "Hya A"  => @perley_spectrum(1.7795, -0.9176, -0.0843, -0.0139, +0.0295),
                   "Vir A"  => @perley_spectrum(2.4466, -0.8116, -0.0483),
                   "3C 286" => @perley_spectrum(1.2481, -0.4507, -0.1798, +0.0357),
                   "3C 295" => @perley_spectrum(1.4701, -0.7658, -0.2780, -0.0347, +0.0399),
                   "3C 353" => @perley_spectrum(1.8627, -0.6938, -0.0998, -0.0732),
                   "3C 380" => @perley_spectrum(1.2320, -0.7909, +0.0947, +0.0976, -0.1794, -0.1566),
                   "Cyg A"  => @perley_spectrum(3.3498, -1.0022, -0.2246, +0.0227, +0.0425))
    spectra
end

function scaife_flux_calibrators()
    spectra = Dict("3C 48"  => @scaife_spectrum(64.768, -0.387, -0.420, +0.181),
                   "3C 147" => @scaife_spectrum(66.738, -0.022, -1.012, +0.549),
                   "Lyn A"  => @scaife_spectrum(83.084, -0.699, -0.110),
                   "3C 286" => @scaife_spectrum(27.477, -0.158, +0.032, -0.180),
                   "3C 295" => @scaife_spectrum(97.763, -0.582, -0.298, +0.583, -0.363),
                   "3C 380" => @scaife_spectrum(77.352, -0.767))
    spectra
end

function baars_flux_calibrators()
    spectra = Dict("Cyg A"  => @baars_spectrum(4.695, +0.085, -0.178))
    spectra
end

const source_direction = Dict("Cyg A"  => Direction(dir"J2000", "19h59m28.35663s", "+40d44m02.0970s"),
                              "Cas A"  => Direction(dir"J2000", "23h23m24s", "58d48m54s"),
                              "Vir A"  => Direction(dir"J2000", "12h30m49.42338s", "+12d23m28.0439s"),
                              "Tau A"  => Direction(dir"J2000", "05h34m31.94s", "+22d00m52.2s"),
                              "Her A"  => Direction(dir"J2000", "16h51m11.4s", "+04d59m20s"),
                              "Hya A"  => Direction(dir"J2000", "09h18m05.651s", "-12d05m43.99s"),
                              "Per B"  => Direction(dir"J2000", "04h37m04.3753s", "+29d40m13.819s"),
                              "3C 353" => Direction(dir"J2000", "17h20m28.147s", "-00d58m47.12s"),
                              "Lyn A"  => Direction(dir"J2000", "08h13m36.05609s", "+48d13m02.6360s"),
                              "3C 48"  => Direction(dir"J2000", "01h37m41.2971s", "+33d09m35.118s"),
                              "3C 147" => Direction(dir"J2000", "05h42m36.2646s", "+49d51m07.083s"),
                              "3C 286" => Direction(dir"J2000", "13h31m08.3s", "+30d30m33s"),
                              "3C 295" => Direction(dir"J2000", "14h11m20.467s", "+52d12m09.52s"),
                              "3C 380" => Direction(dir"J2000", "18h29m31.72483s", "+48d44m46.9515s"))

end

