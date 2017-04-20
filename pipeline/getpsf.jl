function getpsf(spw, dataset, range=0:5:130)
    dir = getdir(spw)
    observation, lmax, mmax = load(joinpath(dir, "observation-matrix-$dataset.jld"),
                                   "blocks", "lmax", "mmax")
    _getpsf(spw, observation, lmax, mmax, range)
end

function _getpsf(spw, observation, lmax, mmax, range)
    dir = getdir(spw)
    psf_dir = joinpath(dir, "psf")
    isdir(psf_dir) || mkdir(psf_dir)

    for θ in range
        output = @sprintf("psf%+03d-degrees.fits", round(Int, 90-θ))
        println(output)
        isfile(joinpath(psf_dir, output)) && continue

        alm = getpsf_alm(observation, deg2rad(θ), lmax, mmax)
        psf = alm2map(alm, 512)
        writehealpix(joinpath(psf_dir, output), psf, replace=true)
    end
end

function pointsource_alm(θ, ϕ, lmax, mmax)
    alm = Alm(Complex128, lmax, mmax)
    for m = 0:mmax, l = m:lmax
        alm[l,m] = conj(BPJSpec.Y(l, m, θ, ϕ))
    end
    alm
end

function getpsf_alm(observation, θ, ϕ, lmax, mmax)
    input_alm = pointsource_alm(θ, ϕ, lmax, mmax)
    output_alm = Alm(Complex128, lmax, mmax)
    for m = 0:mmax
        A = observation[m+1]
        x = [input_alm[l, m] for l = m:lmax]
        y = A*x
        for l = m:lmax
            output_alm[l, m] = y[l-m+1]
        end
    end
    output_alm
end

function getpsf_alm(observation, θ, lmax, mmax)
    getpsf_alm(observation, θ, 0, lmax, mmax)
end

function load_psf(spw)
    dir = joinpath(getdir(spw), "psf")
    files = readdir(dir)

    dec = zeros(length(files))
    for (file_index, file) in enumerate(files)
        m = match(r"psf([\+-]\d\d)-degrees\.fits", file)
        dec[file_index] = deg2rad(parse(Int, m.captures[1]))
    end

    perm = sortperm(dec)
    files = files[perm]
    dec = dec[perm]

    xgrid = linspace(-deg2rad(5.0), +deg2rad(5.0), 201)
    ygrid = linspace(-deg2rad(5.0), +deg2rad(5.0), 201)
    output = zeros(length(xgrid), length(ygrid), length(files))

    for (file_index, file) in enumerate(files)
        psf = readhealpix(joinpath(dir, file))
        image = extract_image(psf, xgrid, ygrid, 0, dec[file_index])
        output[:, :, file_index] = image
    end
    dec, output
end

function interpolate_psf(psf_dec, psf, dec)
    idx = searchsortedlast(psf_dec, dec)
    scale = 1-(dec-psf_dec[idx])/(psf_dec[idx+1]-psf_dec[idx])
    scale*psf[:, :, idx] + (1-scale)*psf[:, :, idx+1]
end

function extract_image(map, xgrid, ygrid, ra, dec)
    direction = Direction(dir"ITRF", ra*radians, dec*radians)
    extract_image(map, xgrid, ygrid, direction)
end

function extract_image(map, direction)
    xgrid = linspace(-deg2rad(5.0), +deg2rad(5.0), 201)
    ygrid = linspace(-deg2rad(5.0), +deg2rad(5.0), 201)
    extract_image(map, xgrid, ygrid, direction)
end

function extract_image(map, xgrid, ygrid, direction)
    up = [direction.x, direction.y, direction.z]
    north = [0, 0, 1] - up*direction.z
    north /= norm(north)
    east = cross(north, up)
    θlist = Float64[]
    ϕlist = Float64[]
    for y in ygrid, x in xgrid
        vector = up + x*east + y*north
        vector /= norm(vector)
        θ = acos(vector[3])
        ϕ = atan2(vector[2], vector[1])
        push!(θlist, θ)
        push!(ϕlist, ϕ)
    end
    image = LibHealpix.interpolate(map, θlist, ϕlist)
    reshape(image, length(xgrid), length(ygrid))
end

