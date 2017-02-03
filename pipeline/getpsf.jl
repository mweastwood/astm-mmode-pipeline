function getpsf(spw, tolerance=0.05)
    dir = getdir(spw)
    isdir(dir) || mkdir(dir)

    transfermatrix = TransferMatrix(joinpath(dir, "transfermatrix"))
    lmax = transfermatrix.lmax
    mmax = transfermatrix.mmax

    dir = joinpath(dir, "psf")
    isdir(dir) || mkdir(dir)

    for θ in linspace(0, 180, 19)
        ϕ = 0
        output_mmodes = @sprintf("mmodes-%03d-degrees", round(Int, θ))
        output_alm = @sprintf("alm-%03d-degrees.jld", round(Int, θ))
        output_healpix = @sprintf("psf-%03d-degrees.fits", round(Int, θ))

        alm = Alm(Complex128, lmax, mmax)
        for m = 0:mmax, l = m:lmax
            alm[l,m] = conj(BPJSpec.Y(l, m, deg2rad(θ), 0))
        end

        mmodes = MModes(joinpath(dir, output_mmodes), mmax, transfermatrix.frequencies)
        _getmodel(transfermatrix, alm, mmodes)
        output = _getalm(transfermatrix, mmodes, tolerance)
        save(joinpath(dir, output_alm), "alm", output)
        #alm = load(joinpath(dir, output_alm), "alm")

        map = alm2map(alm, 512)
        writehealpix(joinpath(dir, output_healpix), map, replace=true)
    end
end

