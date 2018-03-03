function psf_snapshot(spw)
    directory = joinpath(getdir(spw), "psf")
    psf = load(joinpath(directory, "psf.jld"), "psf")
    major, minor, angle = load(joinpath(directory, "gaussian.jld"), "major", "minor", "angle")
    dec, imgs = psf_snapshot_loop(psf, directory)

    ν = getfreq(spw)
    filename = @sprintf("psf-snapshots-%.3fMHz.h5", ν/1e6)
    h5write(joinpath(directory, filename),
            "major-axis", major, "minor-axis", minor, "position-angle", angle,
            "declination", dec, "images", images)
end

function psf_snapshot_loop(psf, directory)
    dec = [90 - rad2deg(LibHealpix.pix2vec_ring(psf.nside, pixel)[1]) for pixel in psf.pixels]
    imgs = zeros(201, 201, length(psf.pixels))

    N = length(psf.pixels)
    lck = ReentrantLock()
    prg = Progress(length(psf.pixels))

    idx = 1
    nextidx() = (myidx = idx; idx += 1; myidx)
    increment() = (lock(lck); next!(prg); unlock(lck))
    output(img, idx) = imgs[:, :, idx] = img

    @sync for worker in workers()
        @async while true
            myidx = nextidx()
            pixel = psf.pixels[myidx]
            img = remotecall_fetch(psf_snapshot_worker, worker, directory, psf.nside, pixel)
            output(img, myidx)
            increment()
        end
    end
    dec, imgs
end

function psf_snapshot_worker(directory, nside, pixel)
    θ, ϕ = LibHealpix.pix2vec_ring(nside, pixel)
    direction = Direction(dir"ITRF", ϕ*radians, (π/2-θ)*radians)
    alm = load(joinpath(directory, @sprintf("%08d.jld", pixel)), "alm")
    map = alm2map(alm, nside)
    img = postage_stamp(map, direction)
    img /= maximum(img)
    img
end

