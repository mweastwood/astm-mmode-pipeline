function haslam()
    width = 20.0
    @time slope, R², mask = haslam(width, "map-restored-registered-rainy-itrf.fits")
    filename = "haslam-spectral-index-updated"
    save(filename*".jld", "slope", slope, "coefficient-of-determination", R², "mask", mask)
end

function haslam(width, filename)
    #println("Preparing Haslam...")
    #haslam = readhealpix(joinpath(workspace, "comparison-maps",
    #                              "haslam408_dsds_Remazeilles2014.fits"))

    #println("Preparing 3...")
    #ν3 = Pipeline.Common.getfreq(18)
    #@time map3 = readhealpix(joinpath(Pipeline.Common.getdir(18), filename))
    #@time map3 = map3 * (BPJSpec.Jy * (BPJSpec.c/ν3)^2 / (2*BPJSpec.k))
    #@time map3 = Pipeline.MModes.rotate_to_galactic(18, "rainy", map3)
    #@time map3 = smooth(map3, 56/60, nside(haslam))

    #save("haslam-checkpoint.jld",
    #     "map3", map3.pixels, "haslam", haslam.pixels)

    map3_pixels, haslam_pixels =
        load("haslam-checkpoint.jld", "map3", "haslam")
    map3 = HealpixMap(map3_pixels)
    haslam = HealpixMap(haslam_pixels)

    println("Constructing mask...")
    mask = haslam_construct_mask(nside(map3))

    println("Fitting...")
    _internal_powerlaw_fit(map3, haslam, mask, width, output_nside=256)
end

function haslam_construct_mask(nside)
    Npix = nside2npix(nside)
    mask = zeros(Bool, Npix)

    meta = Pipeline.Common.getmeta(4, "rainy")
    frame = TTCal.reference_frame(meta)

    sun = measure(frame, Direction(dir"SUN"), dir"GALACTIC")
    sun_vec = [sun.x, sun.y, sun.z]

    cas = measure(frame, Direction(dir"J2000", "23h23m24s", "+58d48m54s"), dir"GALACTIC")
    cas_vec = [cas.x, cas.y, cas.z]

    ncp = measure(frame, Direction(dir"ITRF", 0, 0, 1), dir"GALACTIC")
    ncp_vec = [ncp.x, ncp.y, ncp.z]

    for pix = 1:Npix
        vec = LibHealpix.pix2vec_ring(nside, pix)
        θ, ϕ = LibHealpix.vec2ang(vec)
        if dot(vec, ncp_vec) < cosd(120)
            mask[pix] = true
        elseif dot(vec, sun_vec) > cosd(2)
            mask[pix] = true
        elseif dot(vec, cas_vec) > cosd(5)
            mask[pix] = true
        end
    end
    mask
end

