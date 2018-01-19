function psf_snapshot(spw)
    directory = joinpath(getdir(spw), "psf")
    psf = load(joinpath(directory, "psf.jld"), "psf")
    major, minor, angle = load(joinpath(directory, "gaussian.jld"), "major", "minor", "angle")
    major = major[1:10:end]
    minor = minor[1:10:end]
    angle = angle[1:10:end]
    dec, imgs = psf_snapshot_loop(psf, directory)

    ν = getfreq(spw)
    filename = @sprintf("psf-snapshots-%.3fMHz.h5", ν/1e6)
    h5open(joinpath(directory, filename), "w") do file
        write(file, "major-axis", major)
        write(file, "minor-axis", minor)
        write(file, "position-angle", angle)
        write(file, "declination", dec)
        write(file, "images", imgs)
    end
end

function psf_snapshot_loop(psf, directory)
    pixels = psf.pixels[1:10:end]
    dec = [90 - rad2deg(LibHealpix.pix2ang_ring(psf.nside, pixel)[1]) for pixel in pixels]
    imgs = zeros(201, 201, length(pixels))

    N = length(pixels)
    lck = ReentrantLock()
    prg = Progress(length(pixels))

    idx = 1
    nextidx() = (myidx = idx; idx += 1; myidx)
    increment() = (lock(lck); next!(prg); unlock(lck))
    output(img, idx) = imgs[:, :, idx] = img

    @sync for worker in workers()
        @async while true
            myidx = nextidx()
            myidx > N && break
            pixel = pixels[myidx]
            img = remotecall_fetch(psf_snapshot_worker, worker, directory, psf.nside, pixel)
            output(img, myidx)
            increment()
        end
    end
    dec, imgs
end

function psf_snapshot_worker(directory, nside, pixel)
    θ, ϕ = LibHealpix.pix2ang_ring(nside, pixel)
    direction = Direction(dir"ITRF", ϕ*radians, (π/2-θ)*radians)
    alm = load(joinpath(directory, @sprintf("%08d.jld", pixel)), "alm")
    map = alm2map(alm, nside)
    img = postage_stamp(map, direction)
    img /= maximum(img)
    img
end

