function reconstruct(spw, input_vis="visibilities", output_vis="visibilities-reconstructed", output_mmodes="mmodes-reconstructed", N=10)
    Lumberjack.info("Reconstructing visibilities from spectral window $spw")
    Lumberjack.info("The first $N singular values are being discarded")
    dir = getdir(spw)

    Lumberjack.info("Loading the singular value decomposition")
    U, S, V = load(joinpath(dir, "svd.jld"), "U", "S", "V")

    Lumberjack.info("Computing the reconstructed visibilities")
    visibilities = GriddedVisibilities(joinpath(dir, input_vis))
    S[N+1:end] = 0
    reconstructed = visibilities[1] - U*diagm(S)*V'

    path_to_reconstructed_visibilities = joinpath(dir, output_vis)
    Lumberjack.info("Saving reconstructed visiblities to $path_to_reconstructed_visibilities")
    Nbase = size(reconstructed, 1)
    Ntime = size(reconstructed, 2)
    meta = getmeta(spw)
    β = round(Int, middle(1:Nfreq(meta)))
    ν = meta.channels[β:β]
    origin = 0.0
    visibilities = GriddedVisibilities(path_to_reconstructed_visibilities, Nbase, Ntime, ν, origin)
    visibilities.data[1][:] = reconstructed
    visibilities.weights[1][:] = 1.0

    path_to_mmodes = joinpath(dir, output_mmodes)
    Lumberjack.info("Computing m-modes and saving them to $path_to_mmodes")
    mmodes = MModes(path_to_mmodes, visibilities, 1000)

    nothing
end

