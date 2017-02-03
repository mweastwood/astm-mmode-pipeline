function fitrfi(spw, name = "")
    if name == "A"
        el = 1226.7091391887516
        lon = -118.3147833410907
        lat = 37.145402389570144
    elseif name == "B"
        el = 1214.248326037079
        lon = -118.3852914162684
        lat = 37.3078474772316
    elseif name == "C"
        el = 1232.7690506698564
        lon = -118.37296747772183
        lat = 37.24935118263112
    elseif name == "D"
        el = 1608.21583019197
        lon = -118.23417138204732
        lat = 37.06249388547446
    else
        # source I am currently working on
        #lat, lon, el = (37.25308408843589,-118.39866511291234,1280.922242251347) # 101147.68887263279
        lat, lon, el = (37.24861167954518,-118.36229648059934,1232.6294581335637) # 102113.09594868594)
    end
    fitrfi(spw, lat, lon, el)
end

function fitrfi(spw, lat, lon, el)
    dir = getdir(spw)
    ms = Table(joinpath(dir, "integrated.ms"))
    data = TTCal.read(ms, "DATA")
    meta = Metadata(ms)

    opt = Opt(:LN_COBYLA, 3)
    x0 = [lat, lon, el]
    max_objective!(opt, (x,g)->objective(data, meta, x[1], x[2], x[3]))
    ftol_rel!(opt, 1e-6)
    minf, x, ret = optimize(opt, x0)
    @show ret (x[1], x[2], x[3]) minf
end

function objective(data, meta, lat, lon, el)
    position = Position(pos"WGS84", el*meters, lon*degrees, lat*degrees)
    spectrum = RFISpectrum(meta.channels, ones(StokesVector, Nfreq(meta)))
    rfi = RFISource("RFI", position, spectrum)
    flux = getflux(data, meta, rfi)
    @show lat, lon, el, flux
    flux
end

