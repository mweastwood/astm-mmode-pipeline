function dont_restore(spw)
    if spw == 18
        target = "new-alm-wiener-filtered"
        lmax = mmax = 1500
    else
        target = "alm-wiener-filtered"
        lmax = mmax = 1000
    end
    directory = joinpath(getdir(spw), "cleaning", target)
    residual_alm, degraded_alm, clean_components = load(joinpath(directory, "final.jld"),
                                                        "residual_alm", "degraded_alm",
                                                        "clean_components")
    coeff = load(joinpath(getdir(spw), "map-restored-registered-rainy.jld"), "coeff")

    restored_alm = residual_alm + degraded_alm
    restored_map = alm2map(Alm(lmax, mmax, restored_alm), 2048)
    restored_map = dedistort(restored_map, coeff)
    restored_map = MModes.rotate_to_galactic(spw, "rainy", restored_map)
    MModes.mask_the_map!(spw, restored_map)

    ν = getfreq(spw)
    restored_map *= BPJSpec.Jy * (BPJSpec.c/ν)^2 / (2*BPJSpec.k)

    directory = joinpath(getdir(spw), "uri")
    isdir(directory) || mkdir(directory)
    writehealpix(joinpath(directory, @sprintf("cleaning-residuals-%.3fMHz.fits", ν/1e6)),
                 restored_map, coordsys="G", replace=true)
end

function dont_restore_near_nvss(spw)
    if spw == 18
        target = "new-alm-wiener-filtered"
        lmax = mmax = 1500
    else
        target = "alm-wiener-filtered"
        lmax = mmax = 1000
    end
    directory = joinpath(getdir(spw), "cleaning", target)
    residual_alm, degraded_alm, clean_components = load(joinpath(directory, "final.jld"),
                                                        "residual_alm", "degraded_alm",
                                                        "clean_components")
    coeff = load(joinpath(getdir(spw), "map-restored-registered-rainy.jld"), "coeff")

    directory = joinpath(getdir(spw), "psf")
    psf = load(joinpath(directory, "psf.jld"), "psf")
    major_σ, minor_σ, angle = load(joinpath(directory, "gaussian.jld"), "major", "minor", "angle")

    restored_alm = residual_alm + degraded_alm
    restored_map = alm2map(Alm(lmax, mmax, restored_alm), 2048)
    restore_but_not_near_nvss!(spw, restored_map, clean_components, psf, major_σ, minor_σ, angle)
    restored_map = dedistort(restored_map, coeff)
    restored_map = MModes.rotate_to_galactic(spw, "rainy", restored_map)
    MModes.mask_the_map!(spw, restored_map)

    ν = getfreq(spw)
    restored_map *= BPJSpec.Jy * (BPJSpec.c/ν)^2 / (2*BPJSpec.k)

    directory = joinpath(getdir(spw), "uri")
    isdir(directory) || mkdir(directory)
    writehealpix(joinpath(directory, @sprintf("nvss-removed-%.3fMHz.fits", ν/1e6)),
                 restored_map, coordsys="G", replace=true)
end


function restore_but_not_near_nvss!(spw, restored_map, clean_components, psf, major_σ, minor_σ, angle)
    catalogs = joinpath(dirname(@__FILE__), "..", "..", "workspace", "catalogs")
    nvss = readdlm(joinpath(catalogs, "nvss.txt"), '|', Float64, skipstart=3)
    cluster_catalog = readdlm(joinpath(catalogs, "subMCXC_404.txt"), Float64, skipstart=1)

    # Pair down the list of NVSS sources to just those that are within 1 degree of a galaxy cluster
    nvss_directions = [Direction(dir"GALACTIC",
                                 nvss[idx, 1]*degrees,
                                 nvss[idx, 2]*degrees)
                       for idx = 1:size(nvss, 1)]
    cluster_directions = [Direction(dir"GALACTIC",
                                    cluster_catalog[idx, 1]*degrees,
                                    cluster_catalog[idx, 2]*degrees)
                          for idx = 1:size(cluster_catalog, 1)]

    nvss_directions_saved = Direction[]
    @time for ndir in nvss_directions
        nvec = [ndir.x, ndir.y, ndir.z]
        for cdir in cluster_directions
            cvec = [cdir.x, cdir.y, cdir.z]
            if dot(nvec, cvec) > cosd(1)
                push!(nvss_directions_saved, ndir)
                break
            end
        end
    end
    nvss_directions = nvss_directions_saved

    # Nuke the clean components in the vicinity of these NVSS sources
    meta = getmeta(spw, "rainy")
    frame = TTCal.reference_frame(meta)
    for ndir in nvss_directions
        dir = measure(frame, ndir, dir"ITRF")
        lat  = latitude(dir)
        long = longitude(dir)
        θ = π/2 - lat
        ϕ = long
        disc = query_disc(restored_map, θ, ϕ, deg2rad(10/60))
        for pixel in disc
            clean_components[disc] = 0
        end
    end

    # Now restore the clean components
    restore!(restored_map, clean_components, psf, major_σ, minor_σ, angle)
end

function create_ds9_region_files(catalogs, nvss, cluster_catalog)
    file = open(joinpath(catalogs, "nvss.reg"), "w")
    write(file, "global color=red, edit=0 move=0 delete=1\n")
    write(file, "galactic\n")
    for idx = 1:size(nvss, 1)
        write(file, @sprintf("circle(%f, %f, 10')\n", nvss[idx, 1], nvss[idx, 2]))
    end
    close(file)

    file = open(joinpath(catalogs, "subMCXC_404.reg"), "w")
    write(file, "global color=green, edit=0 move=0 delete=1\n")
    write(file, "galactic\n")
    for idx = 1:size(cluster_catalog, 1)
        write(file, @sprintf("circle(%f, %f, 10')\n", cluster_catalog[idx, 1], cluster_catalog[idx, 2]))
    end
    close(file)
end

