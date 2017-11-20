"""
    ionosphere(spw)

Measure the position and flux of Cas A and Cyg A in every integration. This is the data required by
Esayas for his work on the ionosphere.
"""
function ionosphere(spw)
    dadas = listdadas(spw)
    ionosphere(spw, 1:length(dadas))
end

function ionosphere(spw, range)
    dadas = listdadas(spw)[range]
    Ntime = length(range)
    meta = getmeta(spw)

    idx = 1
    nextidx() = (myidx = idx; idx += 1; myidx)

    p = Progress(Ntime)
    l = ReentrantLock()
    increment_progress() = (lock(l); next!(p); unlock(l))

    times = zeros(Ntime)
    cas_radec = zeros(2, Ntime)
    cas_azel = zeros(2, Ntime)
    cas_flux = zeros(Nfreq(meta), Ntime)
    cyg_radec = zeros(2, Ntime)
    cyg_azel = zeros(2, Ntime)
    cyg_flux = zeros(Nfreq(meta), Ntime)

    @sync for worker in workers()
        @async while true
            myidx = nextidx()
            myidx ≤ Ntime || break
            out = remotecall_fetch(_ionosphere, worker, spw, dadas[myidx])
            _time, _cas_radec, _cas_azel, _cas_flux, _cyg_radec, _cyg_azel, _cyg_flux = out
            times[myidx] = _time
            cas_radec[:, myidx] = _cas_radec
            cas_azel[:, myidx] = _cas_azel
            cas_flux[:, myidx] = _cas_flux
            cyg_radec[:, myidx] = _cyg_radec
            cyg_azel[:, myidx] = _cyg_azel
            cyg_flux[:, myidx] = _cyg_flux
            increment_progress()
        end
    end

    dir = getdir(spw)
    output_file = joinpath(dir, "ionospheric-data-for-esayas.npz")

    # let's do a backup save just in case I fuck up the npz shit again
    output_jld = joinpath(dir, "ionospheric-data-for-esayas.jld")
    save(output_jld, "time", times, "frequency", meta.channels,
         "cas_radec", cas_radec, "cas_azel", cas_azel, "cas_flux", cas_flux,
         "cyg_radec", cyg_radec, "cyg_azel", cyg_azel, "cyg_flux", cyg_flux)

    output = Dict("time" => times, "frequency" => meta.channels,
                  "cas_radec" => cas_radec, "cas_azel" => cas_azel, "cas_flux" => cas_flux,
                  "cyg_radec" => cyg_radec, "cyg_azel" => cyg_azel, "cyg_flux" => cyg_flux)
    npzwrite(output_file, output)

    nothing
end

function _ionosphere(spw, dada)
    ms, path = dada2ms(dada)
    caltimes, cal = readcals(spw)

    old_flag!(ms, spw)
    data = TTCal.read(ms, "DATA")
    meta = Metadata(ms)
    beam = ConstantBeam()
    frame = TTCal.reference_frame(meta)

    # - find the nearest calibration in time and apply it
    time = ms["TIME", 1]
    idx = indmin(abs2(caltimes-time))
    applycal!(data, meta, cal[idx])

    # - flag short baselines
    oldflags = copy(data.flags)
    minuvw = 15.0
    TTCal.flag_short_baselines!(data, meta, minuvw)

    # - fit Cas A
    cas = PointSource("Cas A", Direction(dir"J2000", "23h23m24s", "58d48m54s"),
                      PowerLaw(1, 0, 0, 0, 74e6, [-0.7]))
    if TTCal.isabovehorizon(frame, cas)
        cas_dir = fitvis(data, meta, cas, tolerance=1e-5) :: Direction
        cas_dir_j2000 = measure(frame, cas_dir, dir"J2000")
        cas_dir_azel = measure(frame, cas_dir, dir"AZEL")
        cas_radec = [longitude(cas_dir_j2000), latitude(cas_dir_j2000)]
        cas_azel = [longitude(cas_dir_azel), latitude(cas_dir_azel)]
        cas_spec = getspec(data, meta, cas_dir)
        cas_flux = getfield.(StokesVector.(cas_spec), 1) # just get the Stokes I part
    else
        cas_radec = [0.0, 0.0]
        cas_azel = [0.0, 0.0]
        cas_flux = zeros(109)
    end

    # - fit Cyg A
    cyg = PointSource("Cyg A", Direction(dir"J2000", "19h59m28.35663s", "+40d44m02.0970s"),
                      PowerLaw(1, 0, 0, 0, 74e6, [-0.7]))
    if TTCal.isabovehorizon(frame, cyg)
        cyg_dir = fitvis(data, meta, cyg, tolerance=1e-5) :: Direction
        cyg_dir_j2000 = measure(frame, cyg_dir, dir"J2000")
        cyg_dir_azel = measure(frame, cyg_dir, dir"AZEL")
        cyg_radec = [longitude(cyg_dir_j2000), latitude(cyg_dir_j2000)]
        cyg_azel = [longitude(cyg_dir_azel), latitude(cyg_dir_azel)]
        cyg_spec = getspec(data, meta, cyg_dir)
        cyg_flux = getfield.(StokesVector.(cyg_spec), 1) # just get the Stokes I part
    else
        cyg_radec = [0.0, 0.0]
        cyg_azel = [0.0, 0.0]
        cyg_flux = zeros(109)
    end

    finalize(ms)
    rm(path, recursive=true)

    time, cas_radec, cas_azel, cas_flux, cyg_radec, cyg_azel, cyg_flux
end

