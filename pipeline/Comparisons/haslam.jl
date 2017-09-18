function compare_with_haslam()
    spw = 18
    haslam_freq = 408e6
    lwa_freq = Pipeline.Common.getfreq(spw)
    ν = [lwa_freq; haslam_freq]

    #haslam = readhealpix(joinpath(workspace, "comparison-maps",
    #                              "haslam408_dsds_Remazeilles2014.fits"))
    #dir = Pipeline.Common.getdir(spw)
    #lwa = readhealpix(joinpath(dir, "map-restored-registered-rainy-itrf.fits"))
    #lwa = lwa * (BPJSpec.Jy * (BPJSpec.c/lwa_freq)^2 / (2*BPJSpec.k))
    #@time lwa = Pipeline.MModes.rotate_to_galactic(spw, "rainy", lwa)
    #@time lwa = smooth(lwa, 56/60, nside(haslam))
    #maps = [lwa; haslam]
    #save("haslam-checkpoint.jld", "maps", getfield.(maps, 1))
    maps = HealpixMap.(load("haslam-checkpoint.jld", "maps"))

    @time slope, residual = haslam_fit_line(maps[1], maps[2], 20)
    save("haslam-spectral-index.jld", "slope", slope, "residual", residual)
end

function haslam_fit_line(map1, map2, width)
    output_nside = 256
    output_npix  = nside2npix(output_nside)
    line_slope = zeros(output_npix)
    residual   = zeros(output_npix)

    meta = Pipeline.Common.getmeta(4, "rainy")
    frame = TTCal.reference_frame(meta)
    for idx = 1:output_npix
        θ, ϕ = LibHealpix.pix2ang_ring(output_nside, idx)
        galactic = Direction(dir"GALACTIC", ϕ*radians, (π/2-θ)*radians)
        itrf = measure(frame, galactic, dir"ITRF")
        dec = latitude(itrf) |> rad2deg
        dec < -30 && continue

        disc, weights = _disc_weights(map1, θ, ϕ, width)
        m, res = haslam_fit_line(idx, map1, map2, disc, weights)
        line_slope[idx] = m
        residual[idx] = res
    end
    line_slope, residual
end

function haslam_fit_line(idx, map1, map2, disc, weights)
    x = [map1[pixel] for pixel in disc]
    z = [map2[pixel] for pixel in disc]

    ## Discard extreme points (to reduce sensitivty to point sources)
    #N = length(z)
    #amplitude = hypot.(x, y, z)
    #perm = sortperm(amplitude)
    #perm = perm[1:round(Int, 0.9N)]
    #x = x[perm]
    #y = y[perm]
    #z = z[perm]
    #weights = weights[perm]

    # Fit a line
    e = ones(length(x))
    A = [x e]
    W = Diagonal(weights)
    m_line = (A'*W*A)\(A'*(W*z))
    z_ = m_line[1]*x + m_line[2]
    weight_norm = sqrt(sum(weights))
    residual_norm = sqrt(sum(weights.*abs2(z-z_)))
    data_norm = sqrt(sum(weights.*abs2(z)))

    m_line[1], residual_norm/data_norm
end

