#using PyPlot

function register(spw, dataset, target)
    dir = getdir(spw)
    pixels = load(joinpath(dir, "$target-$dataset.jld"), "map")
    map = HealpixMap(pixels)::HealpixMap

    # For testing (makes things run more quickly)
    #alm = map2alm(map, 1000, 1000)
    #map = alm2map(alm, 256)

    ra, dec, flux = read_vlssr_catalog()
    ra, dec, flux = flux_cutoff(ra, dec, flux, 30)
    ra, dec, flux = near_bright_source_filter(ra, dec, flux)
    ra, dec, flux = too_close_together(ra, dec, flux)
    N = length(flux)
    @show N

    rhat = unit_vector_map(nside(map))
    directions = convert_to_itrf(spw, ra, dec)
    measured_directions = register_centroid(spw, map, directions, rhat)

    ra = longitude.(directions)
    dec = latitude.(directions)
    output_region_file(ra, dec)
    measured_ra = longitude.(measured_directions)
    measured_dec = latitude.(measured_directions)
    for idx = 1:N
        if ra[idx] - measured_ra[idx] > π
            measured_ra[idx] += 2π
        elseif measured_ra[idx] - ra[idx] > π
            measured_ra[idx] -= 2π
        end
    end

    θ = π/2 - measured_dec
    ϕ = ra
    dθ = dec - measured_dec # opposite because dec runs in opposite direction to θ
    dϕ = measured_ra - ra

    coeff = zeros(30)
    xmin  = -10ones(length(coeff))
    xmax  = +10ones(length(coeff))

    opt = Opt(:LN_SBPLX, length(coeff))
    ftol_rel!(opt, 1e-10)
    min_objective!(opt, (x, g)->residual(x, θ, ϕ, dθ, dϕ))
    lower_bounds!(opt, xmin)
    upper_bounds!(opt, xmax)
    minf, coeff, ret = optimize(opt, coeff)

    fix_ra(ra) = rad2deg(mod2pi.(ra + π)-π)/15
    fix_dec(dec) = rad2deg(dec)

    #figure(1); clf()
    #stretch = 50
    #for idx = 1:N
    #    δra = measured_ra[idx] - ra[idx]
    #    δdec = measured_dec[idx] - dec[idx]
    #    plot(fix_ra([ra[idx], ra[idx]+stretch*δra]), fix_dec([dec[idx], dec[idx]+stretch*δdec]), "k-")

    #    _dθ, _dϕ = vector_spherical_harmonics(coeff, θ[idx], ϕ[idx])
    #    plot(fix_ra([ra[idx], ra[idx]+stretch*_dϕ]), fix_dec([dec[idx], dec[idx]-stretch*_dθ]), "r-")

    #    plot(fix_ra(ra[idx]), fix_dec(dec[idx]), "b.")
    #end
    #gca()[:invert_xaxis]()

    map = dedistort(map, coeff)
    writehealpix(joinpath(dir, "$target-registered-$dataset-itrf.fits"), map, replace=true)
    save(joinpath(dir, "$target-registered-$dataset.jld"), "map", map.pixels)
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

    ra = deg2rad(15*(ra_hours + (ra_minutes + ra_seconds/60)/60))
    dec = sign(dec_degrees) .* deg2rad(abs(dec_degrees) + (dec_minutes + dec_seconds/60)/60)

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
        x1 = cos(ra) .* cos(dec)
        y1 = sin(ra) .* cos(dec)
        z1 = sin(dec)
        x2 = cos(_ra) * cos(_dec)
        y2 = sin(_ra) * cos(_dec)
        z2 = sin(_dec)
        acosd(x1*x2 + y1*y2 + z1*z2)
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

function convert_to_itrf(spw, ra, dec)
    meta = getmeta(spw, "rainy")
    frame = TTCal.reference_frame(meta)

    output = Direction[]
    for idx = 1:length(ra)
        j2000 = Direction(dir"J2000", ra[idx]*radians, dec[idx]*radians)
        itrf  = measure(frame, j2000, dir"ITRF")
        push!(output, itrf)
    end
    output
end

function unit_vector_map(nside)
    N = nside2npix(nside)
    rhat = zeros(3, N)
    for pixel = 1:N
        rhat[:, pixel] = LibHealpix.pix2vec_ring(nside, pixel)
    end
    rhat
end

function register_centroid(spw, map, directions, rhat)
    idx = 1
    N = length(directions)
    nextidx() = (idx′ = idx; idx += 1; idx′)
    prg = Progress(N, "Progress: ")
    lck = ReentrantLock()
    increment_progress() = (lock(lck); next!(prg); unlock(lck))
    centroids = similar(directions)
    @sync for worker in workers()
        @async begin
            input  = RemoteChannel()
            output = RemoteChannel()
            try
                remotecall(_register_centroid_loop, worker, spw, map, rhat, input, output)
                while true
                    idx′ = nextidx()
                    idx′ ≤ N || break
                    put!(input, directions[idx′])
                    centroids[idx′] = take!(output)
                    increment_progress()
                end
            catch exception
                println(exception)
            finally
                close(input)
                close(output)
            end
        end
    end
    centroids
end

function _register_centroid_loop(spw, map, rhat, input, output)
    while true
        try
            itrf = take!(input)
            put!(output, _register_centroid(spw, map, itrf, rhat))
        catch exception
            if isa(exception, RemoteException) || isa(exception, InvalidStateException)
                break
            else
                println(exception)
                rethrow(exception)
            end
        end
    end
end

function _register_centroid(spw, map, itrf, rhat)
    aperture = Int[]
    annulus  = Int[]
    for pixel = 1:length(map)
        dotproduct = (rhat[1, pixel]*itrf.x
                      + rhat[2, pixel]*itrf.y
                      + rhat[3, pixel]*itrf.z)
        # I'm seeing cases where the dot product is slightly out of the domain of arccos.
        # Eg. +1.0000000000000002, -1.0000000000000002
        dotproduct = clamp(dotproduct, -1, 1)
        θ = acosd(dotproduct)
        #if θ < 0.25
        if θ < 0.5
            push!(aperture, pixel)
        elseif 3 < θ < 5
            push!(annulus, pixel)
        end
    end

    annulus_pixel_values = [map[pixel] for pixel in annulus]
    background = median(annulus_pixel_values)

    #centroid = [0.0, 0.0, 0.0]
    #for pixel in aperture
    #    centroid += (map[pixel] - background) * rhat[:, pixel]
    #end
    #centroid /= norm(centroid)
    aperture_pixel_values = [map[pixel] for pixel in aperture]
    pixel = aperture[indmax(aperture_pixel_values)]
    centroid = rhat[:, pixel]

    Direction(dir"ITRF", centroid[1], centroid[2], centroid[3])
end

function residual(coeff, θ, ϕ, dθ, dϕ)
    output = 0.0
    N = length(θ)
    for idx = 1:N
        _dθ, _dϕ = vector_spherical_harmonics(coeff, θ[idx], ϕ[idx])
        output += abs2(dθ[idx] - _dθ)
        output += abs2(sin(θ[idx])*(dϕ[idx] - _dϕ))
    end
    output = sqrt(output)
    output
end

function vector_spherical_harmonics(coeff, θ, ϕ)
    dθ = 0.0
    dϕ = 0.0
    count = 1
    for l = 1:3, m = -l:l
        δθ, δϕ = Ψ(l, m, θ, ϕ)
        dθ += coeff[count]*δθ
        dϕ += coeff[count]*δϕ
        count += 1

        δθ, δϕ = Φ(l, m, θ, ϕ)
        dθ += coeff[count]*δθ
        dϕ += coeff[count]*δϕ
        count += 1
    end
    dθ, dϕ
end

# Vector spherical harmonics
# (https://en.wikipedia.org/wiki/Vector_spherical_harmonics)
# We have a real-valued vector field, so we've just taken the real part of the listed vector
# spherical harmonics. We've also dropped the normalizing coefficients to simplify the expressions.

function Ψ(l, m, θ, ϕ)
    dθ = 0.0
    dϕ = 0.0
    if l == 1 && m == 0
        dθ = sin(θ)
    elseif l == 1 && m == 1
        dθ = cos(θ)*cos(ϕ)
        dϕ = -sin(ϕ)
    elseif l == 1 && m == -1
        dθ = cos(θ)*sin(ϕ)
        dϕ = cos(ϕ)
    elseif l == 2 && m == 0
        dθ = sin(θ)*cos(θ)
    elseif l == 2 && m == 1
        dθ = cos(2θ)*cos(ϕ)
        dϕ = -cos(θ)*sin(ϕ)
    elseif l == 2 && m == -1
        dθ = cos(2θ)*sin(ϕ)
        dϕ = cos(θ)*cos(ϕ)
    elseif l == 2 && m == 2
        dθ = sin(θ)*cos(θ)*cos(2ϕ)
        dϕ = -sin(θ)*sin(2ϕ)
    elseif l == 2 && m == -2
        dθ = sin(θ)*cos(θ)*sin(2ϕ)
        dϕ = sin(θ)*cos(2ϕ)
    elseif l == 3 && m == 0
        dθ = sin(θ)*(1-5cos(θ)^2)
    elseif l == 3 && m == 1
        dθ = (1/2)*cos(θ)*(15cos(2θ)-7)*cos(ϕ)
        dϕ = -(5cos(θ)^2-1)*sin(ϕ)
    elseif l == 3 && m == -1
        dθ = (1/2)*cos(θ)*(15cos(2θ)-7)*sin(ϕ)
        dϕ = (5cos(θ)^2-1)*cos(ϕ)
    elseif l == 3 && m == 2
        dθ = (1/4)*(3sin(3θ)-sin(θ))*cos(2ϕ)
        dϕ = -2sin(θ)*cos(θ)*sin(2ϕ)
    elseif l == 3 && m == -2
        dθ = (1/4)*(3sin(3θ)-sin(θ))*sin(2ϕ)
        dϕ = -2sin(θ)*cos(θ)*cos(2ϕ)
    elseif l == 3 && m == 3
        dθ = 3sin(θ)^2*cos(θ)*cos(3ϕ)
        dϕ = -3sin(θ)^2*sin(3ϕ)
    elseif l == 3 && m == -3
        dθ = 3sin(θ)^2*cos(θ)*sin(3ϕ)
        dϕ = -3sin(θ)^2*cos(3ϕ)
    end
    dθ, dϕ
end

function Φ(l, m, θ, ϕ)
    _dθ, _dϕ = Ψ(l, m, θ, ϕ)
    dθ = _dϕ
    dϕ = -_dθ
    dθ, dϕ
end

function dedistort(map, coeff)
    @show coeff
    Npixels  = length(map)
    Nworkers = length(workers())
    chunks = [idx:Nworkers:Npixels for idx = 1:Nworkers]

    output = HealpixMap(Float64, nside(map))
    @time @sync for worker in workers()
        @async begin
            worker_pixels = pop!(chunks)
            worker_output = remotecall_fetch(_dedistort, worker, map, coeff, worker_pixels)
            for (idx, pixel) in enumerate(worker_pixels)
                output[pixel] = worker_output[idx]
            end
        end
    end
    output
end

function _dedistort(map, coeff, pixels::AbstractVector)
    output = zeros(length(pixels))
    for (idx, pixel) in enumerate(pixels)
        output[idx] = _dedistort(map, coeff, pixel)
    end
    output
end

function _dedistort(map, coeff, pix::Integer)
    vec = LibHealpix.pix2vec_ring(nside(map), pix)
    θ, ϕ = LibHealpix.vec2ang(vec)
    dθ, dϕ = vector_spherical_harmonics(coeff, θ, ϕ)

    # Rotate the vector to the xz-plane
    R = [cos(-ϕ) -sin(-ϕ) 0
         sin(-ϕ)  cos(-ϕ) 0
         0        0       1]
    vec = R*vec

    # Rotate by dθ about the y-axis
    R = [cos(-dθ) 0 -sin(-dθ)
         0        1  0
         sin(-dθ) 0  cos(-dθ)]
    vec = R*vec

    # Rotate the vector back out of the xz-plane
    R = [cos(ϕ) -sin(ϕ) 0
         sin(ϕ)  cos(ϕ) 0
         0        0       1]
    vec = R*vec

    # Rotate by dϕ about the z-axis
    R = [cos(dϕ) -sin(dϕ) 0
         sin(dϕ)  cos(dϕ) 0
         0        0       1]
    vec = R*vec

    θ, ϕ = LibHealpix.vec2ang(vec)
    LibHealpix.interpolate(map, θ, ϕ)::Float64
end

