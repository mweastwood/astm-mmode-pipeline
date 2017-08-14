function getpsf_width(spw)
    directory = joinpath(getdir(spw), "psf")
    psf = load(joinpath(directory, "psf.jld"), "psf")
    amplitude, major, minor, angle = _getpsf_width(psf, directory)
    save(joinpath(directory, "gaussian.jld"), "amplitude", amplitude,
         "major", major, "minor", minor, "angle", angle)
    amplitude, major, minor, angle
end

function _getpsf_width(psf, directory)
    N = length(psf.pixels)
    amplitude = zeros(N)
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
                    amplitude[ring], major[ring], minor[ring], angle[ring] = take!(output)
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

    amplitude, major, minor, angle
end

function getpsf_width_worker_loop(input, output, directory)
    while true
        try
            pixel = take!(input)
            alm = load(joinpath(directory, @sprintf("%08d.jld", pixel)), "alm")
            map = alm2map(alm, 2048)
            put!(output, fit_gaussian(map, pixel))
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


function fit_gaussian(map, pixel)
    vec = LibHealpix.pix2vec_ring(nside(map), pixel)
    θ, ϕ = LibHealpix.vec2ang(vec)
    if θ > deg2rad(120)
        return [0.0, 0.0, 0.0, 0.0]
    end

    north = [0, 0, 1]
    north -= dot(north, vec)*vec
    north /= norm(north)
    east = cross(north, vec)

    disc = query_disc(map, θ, ϕ, deg2rad(1))
    Npixels = length(disc)
    xlist = zeros(Npixels) # arcmin
    ylist = zeros(Npixels) # arcmin
    values = zeros(Npixels)
    for (idx, pixel) in enumerate(disc)
        vec′ = LibHealpix.pix2vec_ring(nside(map), Int(pixel))
        xlist[idx] = asind(dot(vec′, east))  * 60
        ylist[idx] = asind(dot(vec′, north)) * 60
        values[idx] = map[pixel]
    end

    function my_residual(params, grad)
        residual(xlist, ylist, values, params[1], params[2], params[3], params[4])
    end

    opt = Opt(:LN_SBPLX, 4)
    ftol_rel!(opt, 1e-10)
    min_objective!(opt, my_residual)
    lower_bounds!(opt, [1, 0, 0, -π/2])
    upper_bounds!(opt, [1e6, 60, 60, +π/2])
    minf, params, ret = optimize(opt, [1, 10, 10, 0])
    params[1], params[2], params[3], params[4]
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
    b = -sin(2θ)/(4σx^2) + sin(2θ)^2/(4σy^2)
    c = sin(θ)^2/(2σx^2) + cos(θ)^2/(2σy^2)
    A*exp(-(a*x^2 + 2b*x*y + c*y^2))
end

