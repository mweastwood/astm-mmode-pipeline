function imagesvd(spw, N)
    Lumberjack.info("Imaging the top residual singular vectors in spectral window $spw")
    dir = getdir(spw)

    Lumberjack.info("Loading the left singular vectors")
    U, S = load(joinpath(dir, "svd.jld"), "U", "S")

    Lumberjack.info("Creating a template measurement set")
    dada = listdadas(spw)[1]
    ms, path = dada2ms(dada)
    meta = collect_metadata(ms, ConstantBeam())
    data = get_data(ms)
    data.data[:] = zero(JonesMatrix)
    finalize(ms)

    outputdir = joinpath(dir, "svd-images")
    isdir(outputdir) || mkdir(outputdir)

    β = round(Int, middle(1:Nfreq(meta)))
    for idx = 1:N
        Lumberjack.info("Imaging singular vector $idx")
        ms = Table(ascii(path))
        visibilities = U[:,idx]
        for α = 1:length(visibilities)
            data.data[α,β] = JonesMatrix(visibilities[α], 0, 0, visibilities[α])
        end
        set_corrected_data!(ms, data)
        finalize(ms)

        fits = joinpath(outputdir, @sprintf("%04d", idx))
        wsclean(path, fits)
    end
end

