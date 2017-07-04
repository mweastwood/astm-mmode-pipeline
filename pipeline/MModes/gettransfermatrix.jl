function gettransfermatrix(spw, dataset)
    lmax = mmax = 1000
    dir = getdir(spw)
    meta = getmeta(spw, dataset)
    β = round(Int, middle(1:Nfreq(meta)))
    meta.channels = meta.channels[β:β]
    beam = readhealpix(joinpath(dir, "beam.fits"))
    path = joinpath(dir, "transfermatrix")
    transfermatrix = TransferMatrix(path, meta, beam, lmax, mmax, 1024)
    nothing
end

