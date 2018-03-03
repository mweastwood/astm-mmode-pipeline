module VLSSr

using JLD
using LibHealpix
using CasaCore.Measures
using ProgressMeter

const path = dirname(@__FILE__)

function process()
    data = readdlm(joinpath(path, "vlssr.txt"), skipstart=2)
    ra_hours = data[:,1]
    ra_minutes = data[:,2]
    ra_seconds = data[:,3]
    dec_degrees = data[:,4]
    dec_minutes = data[:,5]
    dec_seconds = data[:,6]
    flux = data[:,8]

    ra = deg2rad(15*(ra_hours + (ra_minutes + ra_seconds/60)/60))
    dec = sign(dec_degrees) .* deg2rad(abs(dec_degrees) + (dec_minutes + dec_seconds/60)/60)
    save(joinpath(path, "vlssr.jld"), "ra", ra, "dec", dec, "flux", flux)
    nothing
end

function select()
    ra, dec, flux = load(joinpath(path, "vlssr.jld"), "ra", "dec", "flux")
    N = length(flux)
    idx = 1
    nextidx() = (myidx = idx; idx += 1; myidx)
    p = Progress(N, "Progress: ")
    l = ReentrantLock()
    increment_progress() = (lock(l); next!(p); unlock(l))
    ds9_region_file = open(joinpath(path, "vlssr.reg"), "w")
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
                remotecall(worker, select_worker_loop, input, output)
                while true
                    myidx = nextidx()
                    myidx ≤ N || break
                    myra   =   ra[myidx]
                    mydec  =  dec[myidx]
                    myflux = flux[myidx]
                    if myflux ≥ 1 && mydec != 0
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

function select_worker_loop(input, output)
    map = readhealpix(joinpath(path, "alm-svd-rfi-suppression.fits"))
    x, y, z = getxyz(map)
    frame = ReferenceFrame()
    while true
        ra, dec = take!(input)
        j2000 = Direction(dir"J2000", ra*radians, dec*radians)
        galactic = measure(frame, j2000, dir"GALACTIC")
        myflux, mynoise = getflux(map, galactic, x, y, z)
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
        if angle < 0.25
            push!(aperture, map[pix])
        elseif 3 < angle < 5
            push!(annulus, map[pix])
        end
    end
    flux = maximum(aperture) - median(annulus)
    noise = median(abs(annulus - median(annulus)))
    flux, noise
end

end

