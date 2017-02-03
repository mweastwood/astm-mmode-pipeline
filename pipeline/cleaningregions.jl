function cleaningregions(spw)
    ra, dec, flux = load(joinpath(workspace, "catalogs/vlssr.jld"), "ra", "dec", "flux")
    N = length(flux)
    @show N
    error("stop")
    idx = 1
    nextidx() = (myidx = idx; idx += 1; myidx)
    p = Progress(N, "Progress: ")
    l = ReentrantLock()
    increment_progress() = (lock(l); next!(p); unlock(l))
    dir = getdir(spw)
    ds9_region_file = open(joinpath(dir, "vlssr.reg"), "w")
    println(ds9_region_file, "global color=red edit=0 move=0 delete=1")
    println(ds9_region_file, "fk5")
    function write_out(ra, dec, significance)
        lock(l)
        ra_str  = sexagesimal( ra, digits=2, hours=true)
        dec_str = sexagesimal(dec, digits=1)
        println(ds9_region_file, @sprintf("circle(%s,%s,%d\")", ra_str, dec_str, 100significance))
        unlock(l)
    end
    @sync for worker in workers()
        @async begin
            input  = RemoteRef()
            output = RemoteRef()
            try
                remotecall(worker, cleaningregions_worker_loop, spw, input, output)
                while true
                    myidx = nextidx()
                    myidx ≤ N || break
                    myra   =   ra[myidx]
                    mydec  =  dec[myidx]
                    myflux = flux[myidx]
                    #if myflux ≥ 1 && mydec != 0
                    if mydec != 0
                        put!(input, (myra, mydec))
                        significance = take!(output)
                        if significance ≥ 3
                            write_out(myra, mydec, significance)
                        end
                    end
                    increment_progress()
                end
            finally
                close(input)
                close(output)
            end
        end
    end
    close(ds9_region_file)
    nothing
end

function cleaningregions_worker_loop(spw, input, output)
    dir = getdir(spw)
    map = readhealpix(joinpath(dir, "map-reconstructed-2048.fits"))
    x, y, z = getxyz(map)
    meta = getmeta(spw)
    frame = TTCal.reference_frame(meta)
    while true
        ra, dec = take!(input)
        j2000 = Direction(dir"J2000", ra*radians, dec*radians)
        j2016 = measure(frame, j2000, dir"JTRUE")
        myflux, mynoise = getflux(map, j2016, x, y, z)
        put!(output, myflux/mynoise)
    end
end

function getxyz(map)
    x = HealpixMap(Float64, nside(map))
    y = HealpixMap(Float64, nside(map))
    z = HealpixMap(Float64, nside(map))
    for pix in 1:length(map)
        vec = LibHealpix.pix2vec_ring(nside(map), pix)
        x[pix] = vec[1]
        y[pix] = vec[2]
        z[pix] = vec[3]
    end
    x, y, z
end

function getflux(map, direction, x, y, z)
    aperture = Float64[]
    annulus  = Float64[]
    for pix = 1:length(map)
        dotproduct = direction.x*x[pix] + direction.y*y[pix] + direction.z*z[pix]
        angle = acosd(dotproduct)
        if angle < 0.1
            push!(aperture, map[pix])
        elseif 3 < angle < 5
            push!(annulus, map[pix])
        end
    end
    flux = maximum(aperture) - median(annulus)
    noise = median(abs(annulus - median(annulus)))
    flux, noise
end

