function gettransfermatrix(spw, dataset, lmax=1000; nside=2048)
    mmax = lmax
    dir = getdir(spw)
    meta = getmeta(spw, dataset)
    β = round(Int, middle(1:Nfreq(meta)))
    meta.channels = meta.channels[β:β]
    beam = readhealpix(joinpath(dir, "beam-$nside.fits"))
    path = joinpath(dir, "transfermatrix-$lmax-$mmax")
    # TEST
    #variables = BPJSpec.TransferMatrixVariables(meta, lmax, mmax, nside)
    #α = 30741
    #return @time BPJSpec.fringes(beam, variables, meta.channels[1], α)
    # TEST
    transfermatrix = TransferMatrix(path, meta, beam, lmax, mmax, nside)
    nothing
end

