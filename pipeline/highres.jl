function high_resolution_imaging(;docalc=true, λ=10,threshold=100)
    spw = 18
    integrations = 3315:4971
    N = length(integrations)
    dadas = listdadas(spw)

    center_ra = sexagesimal("23h23m24s")
    center_dec = sexagesimal("58d48m54s")
    num_ra = 41
    num_dec = 41
    width_ra = deg2rad(1.0)
    width_dec = deg2rad(1.0)
    ra = linspace(center_ra - width_ra/2, center_ra + width_ra/2, num_ra)
    dec = linspace(center_dec - width_dec/2, center_dec + width_dec/2, num_dec)
    Npix = num_ra*num_dec

    if docalc
        Npix = num_ra*num_dec
        AA = zeros(Complex128, Npix, Npix)
        Ab = zeros(Complex128, Npix)

        idx = 1
        nextidx() = (myidx = idx; idx += 1; myidx)
        idx2params(idx) = integrations[idx]

        p = Progress(N, "Progress: ")
        l = ReentrantLock()
        increment_progress() = (lock(l); next!(p); unlock(l))

        update_shit(myAA, myAb) = (AA += myAA, Ab += myAb)

        @sync for worker in workers()
            @async while true
                myidx = nextidx()
                myidx ≤ N || break
                integration = idx2params(myidx)
                file = dadas[integration]
                path = joinpath(getdir(spw), "tmp", "getcyg-"*replace(basename(file), ".dada", ".jld"))
                myAA, myAb = remotecall_fetch(high_resolution_matrices, worker, path, ra, dec)
                remotecall_fetch(gc, worker) # why don't the workers ever free memory, WTF
                #myAA, myAb = high_resolution_matrices(path, ra, dec)
                update_shit(myAA, myAb)
                increment_progress()
            end
        end

        save("/dev/shm/mweastwood/AA_Ab.jld", "AA", AA, "Ab", Ab)
    else
        AA, Ab = load("/dev/shm/mweastwood/AA_Ab.jld", "AA", "Ab")
    end

    λ *= N
    AA += λ*I
    @time x = real(AA\Ab)
    @time image = reshape(x, (num_dec, num_ra))
    image[image .< threshold] = 0

    components = TTCal.Source[]
    for idx = 1:length(ra), jdx = 1:length(dec)
        if image[jdx, idx] != 0
            dir = Direction(dir"J2000", ra[idx]*radians, dec[jdx]*radians)
            pixel = PointSource("pixel", dir, PowerLaw(image[jdx, idx], 0, 0, 0, 1e6, [0.0]))
            push!(components, pixel)
        end
    end
    cas = MultiSource("Cas A", components)
    writesources("/dev/shm/mweastwood/cas-image.json", [cas])

    rad2deg(ra), rad2deg(dec), image
end

function high_resolution_matrices(path, ra, dec)
    data, meta = retry(load; n=3)(path, "data", "meta")
    beam = ConstantBeam()

    f = zeros(Bool, Nbase(meta))
    b = zeros(Complex128, Nbase(meta))
    for α = 1:Nbase(meta)
        f[α] = data.flags[α, 1]
        b[α] = 0.5*(data.data[α, 1].xx + data.data[α, 1].yy)
    end

    Npix = length(ra)*length(dec)
    model = zeros(JonesMatrix, Nbase(meta), Nfreq(meta))
    A = zeros(Complex128, Nbase(meta), Npix)
    for idx = 1:length(ra), jdx = 1:length(dec)
        dir = Direction(dir"J2000", ra[idx]*radians, dec[jdx]*radians)
        pixel = PointSource("pixel", dir, PowerLaw(1.0, 0, 0, 0, 1e6, [0.0]))
        model[:] = zero(JonesMatrix)
        TTCal.genvis_onesource!(model, meta, beam, pixel)
        #model = genvis(meta, beam, pixel)
        kdx = (idx-1)*length(dec) + jdx
        for α = 1:Nbase(meta)
            A[α, kdx] = 0.5*(model[α, 1].xx + model[α, 1].yy)
        end
    end

    bf = b[!f]
    Af = A[!f, :]
    AA = Af'*Af
    Ab = Af'*bf
    AA, Ab
end

