function gettransfermatrix(spw)
    lmax = mmax = 1000
    dir = getdir(spw)
    meta = getmeta(spw)
    β = round(Int, middle(1:Nfreq(meta)))
    meta.channels = meta.channels[β:β]
    beam = readhealpix(joinpath(dir, "beam-map.fits"))
    path = joinpath(dir, "transfermatrix")
    transfermatrix = TransferMatrix(path, meta, beam, lmax, mmax, 1024)
    nothing
end

