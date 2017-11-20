function getpsf_width(spw)
    directory = joinpath(getdir(spw), "psf")
    psf = load(joinpath(directory, "psf.jld"), "psf")
    major, minor, angle = _getpsf_width(psf, directory)
    save(joinpath(directory, "gaussian.jld"), "major", major, "minor", minor, "angle", angle)
    major, minor, angle
end

function _getpsf_width(psf, directory)
    N = length(psf.pixels)
    major = zeros(N)
    minor = zeros(N)
    angle = zeros(N)

    ring = 1
    nextring() = (ring′ = ring; ring += 1; ring′)

    prg = Progress(N)
    lck = ReentrantLock()
    increment_progress() = (lock(lck); next!(prg); unlock(lck))
    @sync for worker in workers()
        @async begin
            input  = RemoteChannel()
            output = RemoteChannel()
            try
                remotecall(getpsf_width_worker_loop, worker, input, output, directory)
                while true
                    ring′ = nextring()
                    ring′ ≤ N || break
                    put!(input, psf.pixels[ring′])
                    major[ring′], minor[ring′], angle[ring′] = take!(output)
                    increment_progress()
                end
            finally
                close(input)
                close(output)
            end
        end
    end

    #for ring = 1:N
    #    pixel = psf.pixels[ring]
    #    alm = load(joinpath(directory, @sprintf("%08d.jld", pixel)), "alm")
    #    map = alm2map(alm, 2048)
    #    fit_gaussian(map, pixel)
    #    amplitude[ring], major[ring], minor[ring], angle[ring] = fit_gaussian(map, pixel)
    #    next!(prg)
    #end

    major, minor, angle
end

function getpsf_width_worker_loop(input, output, directory)
    while true
        try
            pixel = take!(input)
            θ, ϕ = LibHealpix.pix2vec_ring(2048, pixel)
            if θ > deg2rad(120)
                put!(output,  (0.0, 0.0, 0.0))
            else
                alm = load(joinpath(directory, @sprintf("%08d.jld", pixel)), "alm")
                map = alm2map(alm, 2048)
                put!(output, fit_gaussian(map, pixel))
            end
        catch exception
            if isa(exception, RemoteException) || isa(exception, InvalidStateException)
                break
            else
                dump(exception)
                rethrow(exception)
            end
        end
    end
end


function fit_gaussian(map, pixel)
    vec = LibHealpix.pix2vec_ring(nside(map), pixel)
    θ, ϕ = LibHealpix.vec2ang(vec)
    map.pixels[:] = map.pixels / map[pixel]

    side_length = 1
    xlist = linspace(-deg2rad(side_length), +deg2rad(side_length), 1001)
    ylist = linspace(-deg2rad(side_length), +deg2rad(side_length), 1001)
    direction = Direction(dir"ITRF", ϕ*radians, (π/2-θ)*radians)
    values = postage_stamp(map, xlist, ylist, direction)

    # Compute the major and minor axes
    keep_y, keep_x = findn(values .> 0.5)
    count = length(keep_x)
    x = xlist[keep_x]
    y = ylist[keep_y]
    A = [x y]
    U, S, V = svd(A)
    major_axis = V[:, 1]
    minor_axis = V[:, 2]
    major_scale = S[1]
    minor_scale = S[2]

    # Compute the FWHM by assuming all pixels > 0.5 fill an elliptical aperture
    dΩ = ((2side_length)^2 / (180/π)^2) / (length(xlist)*length(ylist))
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

    major_σ, minor_σ, angle
end

function residual(xlist, ylist, values, A, σx, σy, θ)
    output = 0.0
    for (x, y, value) in zip(xlist, ylist, values)
        output += abs2(gaussian(x, y, A, σx, σy, θ) - value)
    end
    sqrt(output)
end

function gaussian(x, y, A, σx, σy, θ)
    a = cos(θ)^2/(2σx^2) + sin(θ)^2/(2σy^2)
    b = sin(2θ)/(4σx^2) - sin(2θ)/(4σy^2)
    c = sin(θ)^2/(2σx^2) + cos(θ)^2/(2σy^2)
    A*exp(-(a*y^2 + 2b*x*y + c*x^2))
end

