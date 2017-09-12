#function compare_with_haslam()
#    haslam = readhealpix(joinpath(workspace, "comparison-maps", "haslam408_dsds_Remazeilles2014.fits"))
#    haslam_freq = 408e6
#
#    # There's a type instability in here somewhere because loading from disk makes the power law
#    # fitting code way faster.
#
#    #lwa = HealpixMap[]
#    #for spw = 4:2:18
#    #    @show spw
#    #    ν = Pipeline.Common.getfreq(spw)
#    #    dir = Pipeline.Common.getdir(spw)
#    #    map = readhealpix(joinpath(dir, "map-wiener-filtered-rainy-2048-galactic.fits"))
#    #    map = smooth(map, 56/60, nside(haslam))
#    #    map = map * (BPJSpec.Jy * (BPJSpec.c/ν)^2 / (2*BPJSpec.k))
#    #    push!(lwa, map)
#    #    writehealpix("tmp/$spw.fits", map, replace=true)
#    #end
#    lwa = HealpixMap[readhealpix("tmp/$spw.fits") for spw = 4:2:18]
#    lwa_freq = Float64[Pipeline.Common.getfreq(spw) for spw = 4:2:18]
#
#    # Fit a power law to each pixel
#    ν = [lwa_freq; haslam_freq]
#    maps = [lwa; haslam]
#
#    N = length(haslam)
#    flags = zeros(Bool, N)
#    spectral_index = zeros(N)
#
#    A = [log10(ν/70e6) ones(length(ν))]
#    prg = Progress(N)
#    for pixel = 1:N
#        y = [map[pixel] for map in maps]
#        keep = y .> 0
#        if sum(keep) ≥ 2
#            line = A[keep, :]\log10(y[keep])
#            spectral_index[pixel] = line[1]
#        else
#            flags[pixel] = true
#        end
#        next!(prg)
#    end
#
#    index_map = HealpixMap(spectral_index)
#    img = mollweide(index_map)
#
#    #figure(1); clf()
#    #writehealpix("index_map.fits", index_map, replace=true)
#    #index_map = readhealpix("index_map.fits")
#    #imshow(mollweide(index_map), vmin=-2.8, vmax=-2.2, cmap=get_cmap("RdBu"))
#    #colorbar()
#
#    save(joinpath("../workspace/comparison-with-haslam.jld"), "index", img)
#end

