function fitrfi(spw, target="calibrated-visibilities")
    dir = getdir(spw)
    data, flags = load(joinpath(dir, target*".jld"), "data", "flags")
    if spw == 4
        fitrfi_spw04(data, flags, target)
    elseif spw == 6
        fitrfi_spw06(data, flags, target)
    elseif spw == 8
        fitrfi_spw08(data, flags, target)
    elseif spw == 10
        fitrfi_spw10(data, flags, target)
    elseif spw == 12
        fitrfi_spw12(data, flags, target)
    elseif spw == 14
        fitrfi_spw14(data, flags, target)
    elseif spw == 16
        fitrfi_spw16(data, flags, target)
    elseif spw == 18
        fitrfi_spw18(data, flags, target)
    end
    nothing
end

macro fitrfi_preamble(spw)
    output = quote
        spw = $spw
        dadas = listdadas(spw, "100hr")
        ms, ms_path = dada2ms(dadas[1])
        finalize(ms)
    end
    esc(output)
end

macro fitrfi_start(spw)
    output = quote
        @fitrfi_preamble $spw
        meta, visibilities = fitrfi_start(spw, data, flags, ms_path, target)
    end
    esc(output)
end

function fitrfi_start(spw, data, flags, ms_path, target) :: Tuple{Metadata, Visibilities}
    meta, visibilities = fitrfi_sum_the_visibilities(spw, data, flags)
    fitrfi_image_visibilities(spw, ms_path, "fitrfi-start-"*target, meta, visibilities)
    meta, visibilities
end

function fitrfi_sum_the_visibilities(spw, data, flags)
    _, Nbase, Ntime = size(data)
    meta = getmeta(spw)
    meta.channels = meta.channels[55:55]
    beam = ConstantBeam()
    visibilities = Visibilities(Nbase, 1)
    visibilities.flags[:] = true
    for idx = 1:Ntime, α = 1:Nbase
        if !flags[α, idx]
            xx = data[1, α, idx]
            yy = data[2, α, idx]
            visibilities.data[α, 1] += JonesMatrix(xx, 0, 0, yy)
            visibilities.flags[α, 1] = false
        end
    end
    TTCal.flag_short_baselines!(visibilities, meta, 15.0)
    meta, visibilities
end

const fitrfi_source_dictionary = Dict(
    :A => (37.145402389570144, -118.3147833410907,  1226.7091391887516), # Big Pine
    :B => (37.3078474772316,   -118.3852914162684,  1214.248326037079),  # Bishop
    :C => (37.24861167954518,  -118.36229648059934, 1232.6294581335637), # Keough's Hot Springs
    :D => (37.06249388547446,  -118.23417138204732, 1608.21583019197),
    # the following locations were eye-balled by Marin
    :B2 => (37.323000, -118.401953, 1214.248326037079), # the northern most source in the triplet
    :B3 => (37.320125, -118.377464, 1214.248326037079)  # the middle source in the triplet
)

function fitrfi_known_source(visibilities, meta, lat, lon, el)
    position = Position(pos"WGS84", el*meters, lon*degrees, lat*degrees)
    spectrum = RFISpectrum(meta.channels, ones(StokesVector, 1))
    rfi = RFISource("RFI", position, spectrum)
    stokes = StokesVector(getspec(visibilities, meta, rfi)[1])
    spectrum = RFISpectrum(meta.channels, [stokes])
    RFISource("RFI", position, spectrum)
end

function fitrfi_unknown_source()
    direction = Direction(dir"AZEL", 0degrees, 90degrees)
    spectrum = PowerLaw(1, 0, 0, 0, 1e6, [0.0])
    PointSource("RFI", direction, spectrum)
end

macro fitrfi_construct_sources(args...)
    output = quote
        sources = TTCal.Source[]
    end
    for arg in args
        if haskey(fitrfi_source_dictionary, arg)
            lat, lon, el = fitrfi_source_dictionary[arg]
            expr = :(push!(sources, fitrfi_known_source(visibilities, meta, $lat, $lon, $el)))
            push!(output.args, expr)
        elseif isa(arg, Integer)
            unknown_sources = fill(fitrfi_unknown_source(), arg)
            expr = :(sources = [sources; $unknown_sources])
            push!(output.args, expr)
        end
    end
    esc(output)
end

macro fitrfi_peel_sources()
    output = quote
        calibrations = fitrfi_peel(meta, visibilities, sources)
    end
    esc(output)
end

function fitrfi_peel(meta, visibilities, sources)
    for source in sources
        println(source)
    end
    beam = ConstantBeam()
    peel!(visibilities, meta, beam, sources, peeliter=10, maxiter=200, tolerance=1e-5)
end

macro fitrfi_finish()
    output = quote
        #fitrfi_image_models(spw, ms_path, meta, sources, target)
        fitrfi_image_corrupted_models(spw, ms_path, meta, sources, calibrations, target)
        fitrfi_image_visibilities(spw, ms_path, "fitrfi-finish-"*target, meta, visibilities)
        xx, yy = fitrfi_output(spw, meta, sources, calibrations, target)
    end
    esc(output)
end

function fitrfi_output(spw, meta, sources, calibrations, target)
    N = length(sources)
    xx = zeros(Complex128, Nbase(meta), N)
    yy = zeros(Complex128, Nbase(meta), N)
    beam = ConstantBeam()
    for idx = 1:N
        model = genvis(meta, beam, sources[idx])
        corrupt!(model, meta, calibrations[idx])
        for α = 1:Nbase(meta)
            xx[α, idx] = model.data[α, 1].xx
            yy[α, idx] = model.data[α, 1].yy
        end
    end
    dir = getdir(spw)
    save(joinpath(dir, target*"-rfi-components.jld"), "xx", xx, "yy", yy)
    xx, yy
end

function fitrfi_image_visibilities(spw, ms_path, image_name, meta, visibilities)
    beam = ConstantBeam()
    dir = getdir(spw)
    output_visibilities = Visibilities(Nbase(meta), 109)
    output_visibilities.flags[:] = true
    output_visibilities.flags[:, 55] = visibilities.flags[:, 1]
    output_visibilities.data[:, 55] = visibilities.data[:, 1]
    ms = Table(ms_path)
    TTCal.write(ms, "DATA", output_visibilities)
    finalize(ms)
    wsclean(ms_path, joinpath(dir, "tmp", image_name), j=8)
end

function fitrfi_image_models(spw, ms_path, meta, sources, target)
    beam = ConstantBeam()
    dir = getdir(spw)
    output_visibilities = Visibilities(Nbase(meta), 109)
    output_visibilities.flags[:] = true
    output_visibilities.flags[:, 55] = false
    for idx = 1:length(sources)
        model = genvis(meta, beam, sources[idx])
        output_visibilities.data[:, 55] = model.data[:, 1]
        ms = Table(ms_path)
        TTCal.write(ms, "DATA", output_visibilities)
        finalize(ms)
        wsclean(ms_path, joinpath(dir, "tmp", "fitrfi-pristine-model-"*target*"-$idx"), j=8)
    end
end

function fitrfi_image_corrupted_models(spw, ms_path, meta, sources, calibrations, target)
    beam = ConstantBeam()
    dir = getdir(spw)
    output_visibilities = Visibilities(Nbase(meta), 109)
    output_visibilities.flags[:] = true
    output_visibilities.flags[:, 55] = false
    for idx = 1:length(sources)
        model = genvis(meta, beam, sources[idx])
        corrupt!(model, meta, calibrations[idx])
        output_visibilities.data[:, 55] = model.data[:, 1]
        ms = Table(ms_path)
        TTCal.write(ms, "DATA", output_visibilities)
        finalize(ms)
        wsclean(ms_path, joinpath(dir, "tmp", "fitrfi-corrupted-model-"*target*"-$idx"), j=8)
    end
end

function fitrfi_spw04(data, flags, target)
end

function fitrfi_spw06(data, flags, target)
end

function fitrfi_spw08(data, flags, target)
end

function fitrfi_spw10(data, flags, target)
end

function fitrfi_spw12(data, flags, target)
end

function fitrfi_spw14(data, flags, target)
end

function fitrfi_spw16(data, flags, target)
end

function fitrfi_spw18(data, flags, target)
    @fitrfi_start 18
    if target == "calibrated-visibilities"
        @fitrfi_construct_sources C A B 2
    elseif target == "calibrated-rainy-visibilities"
        @fitrfi_construct_sources 3
    else
        Lumberjack.error("unknown target")
    end
    @fitrfi_peel_sources
    @fitrfi_finish
end

#function fitrfi_spw04(data, flags)
#    spw = 4
#    dadas = listdadas(spw)
#    ms, ms_path = dada2ms(dadas[1])
#    finalize(ms)
#
#    meta, visibilities0 = fitrfi_start(spw, data, flags, ms_path, checkpoint=true)
#
#    lat, lon, el = source_dictionary("B")
#    N = 1
#    rfi1, visibilities1, calibrations1 = fitrfi_do_source(spw, meta, visibilities0, ms_path,
#                                                          lat, lon, el, 1, N, checkpoint=true)
#
#    #lat, lon, el = source_dictionary("A")
#    #N = 1
#    #rfi2, visibilities2, calibrations2 = fitrfi_do_source(spw, meta, visibilities1, ms_path,
#    #                                                      lat, lon, el, 2, N, checkpoint=false)
#
#    rfi = rfi1
#    calibrations = calibrations1
#    fitrfi_image_corrupted_models(spw, ms_path, meta, rfi, calibrations)
#    fitrfi_output(spw, meta, rfi1, calibrations)
#end
#
#function fitrfi_spw06(data, flags)
#    spw = 6
#    dadas = listdadas(spw)
#    ms, ms_path = dada2ms(dadas[1])
#    finalize(ms)
#
#    meta, visibilities0 = fitrfi_start(spw, data, flags, ms_path, checkpoint=true)
#
#    lat, lon, el = source_dictionary("B")
#    N = 1
#    rfi1, visibilities1, calibrations1 = fitrfi_do_source(spw, meta, visibilities0, ms_path,
#                                                          lat, lon, el, 1, N, checkpoint=true)
#
#    lat, lon, el = source_dictionary("A")
#    N = 1
#    rfi2, visibilities2, calibrations2 = fitrfi_do_source(spw, meta, visibilities1, ms_path,
#                                                          lat, lon, el, 2, N, checkpoint=false)
#
#    rfi = [rfi1; rfi2]
#    calibrations = [calibrations1; calibrations2]
#    fitrfi_image_corrupted_models(spw, ms_path, meta, rfi, calibrations)
#    fitrfi_output(spw, meta, rfi1, calibrations)
#end
#
#function fitrfi_spw08(data, flags)
#    spw = 8
#    dadas = listdadas(spw)
#    ms, ms_path = dada2ms(dadas[1])
#    finalize(ms)
#
#    meta, visibilities0 = fitrfi_start(spw, data, flags, ms_path, checkpoint=true)
#
#    lat, lon, el = source_dictionary("A")
#    N = 1
#    rfi1, visibilities1, calibrations1 = fitrfi_do_source(spw, meta, visibilities0, ms_path,
#                                                          lat, lon, el, 1, N, checkpoint=true)
#
#    lat, lon, el = source_dictionary("B")
#    N = 1
#    rfi2, visibilities2, calibrations2 = fitrfi_do_source(spw, meta, visibilities1, ms_path,
#                                                          lat, lon, el, 2, N, checkpoint=false)
#
#    rfi = [rfi1; rfi2]
#    calibrations = [calibrations1; calibrations2]
#    fitrfi_image_corrupted_models(spw, ms_path, meta, rfi, calibrations)
#    fitrfi_output(spw, meta, rfi1, calibrations)
#end
#
#function fitrfi_spw10(data, flags)
#    spw = 10
#    dadas = listdadas(spw)
#    ms, ms_path = dada2ms(dadas[1])
#    finalize(ms)
#
#    meta, visibilities0 = fitrfi_start(spw, data, flags, ms_path, checkpoint=true)
#
#    lat, lon, el = source_dictionary("B")
#    N = 1
#    rfi1, visibilities1, calibrations1 = fitrfi_do_source(spw, meta, visibilities0, ms_path,
#                                                          lat, lon, el, 1, N, checkpoint=true)
#
#    lat, lon, el = source_dictionary("A")
#    N = 2
#    rfi2, visibilities2, calibrations2 = fitrfi_do_source(spw, meta, visibilities1, ms_path,
#                                                          lat, lon, el, 2, N, checkpoint=true)
#
#    lat, lon, el = source_dictionary("C")
#    N = 2
#    rfi3, visibilities3, calibrations3 = fitrfi_do_source(spw, meta, visibilities2, ms_path,
#                                                          lat, lon, el, 3, N, checkpoint=false)
#
#    rfi = [rfi1; rfi2; rfi3]
#    calibrations = [calibrations1; calibrations2; calibrations3]
#    fitrfi_image_corrupted_models(spw, ms_path, meta, rfi, calibrations)
#    fitrfi_output(spw, meta, rfi1, calibrations)
#end
#
#function fitrfi_spw12(data, flags)
#    spw = 12
#    dadas = listdadas(spw)
#    ms, ms_path = dada2ms(dadas[1])
#    finalize(ms)
#
#    meta, visibilities0 = fitrfi_start(spw, data, flags, ms_path, checkpoint=true)
#
#    lat, lon, el = source_dictionary("B")
#    N = 3
#    rfi1, visibilities1, calibrations1 = fitrfi_do_source(spw, meta, visibilities0, ms_path,
#                                                          lat, lon, el, 1, N, checkpoint=true)
#
#    rfi = rfi1
#    calibrations = calibrations1
#    fitrfi_image_corrupted_models(spw, ms_path, meta, rfi, calibrations)
#    fitrfi_output(spw, meta, rfi1, calibrations)
#end
#
#function fitrfi_spw14(data, flags)
#    spw = 14
#    dadas = listdadas(spw)
#    ms, ms_path = dada2ms(dadas[1])
#    finalize(ms)
#
#    meta, visibilities0 = fitrfi_start(spw, data, flags, ms_path, checkpoint=true)
#
#    lat, lon, el = source_dictionary("A")
#    N = 1
#    rfi1, visibilities1, calibrations1 = fitrfi_do_source(spw, meta, visibilities0, ms_path,
#                                                          lat, lon, el, 1, N, checkpoint=true)
#
#    lat, lon, el = source_dictionary("C")
#    N = 1
#    rfi2, visibilities2, calibrations2 = fitrfi_do_source(spw, meta, visibilities1, ms_path,
#                                                          lat, lon, el, 2, N, checkpoint=true)
#
#    lat, lon, el = source_dictionary("B")
#    N = 3
#    rfi3, visibilities3, calibrations3 = fitrfi_do_source(spw, meta, visibilities2, ms_path,
#                                                          lat, lon, el, 3, N, checkpoint=true)
#
#    rfi = [rfi1; rfi2; rfi3]
#    calibrations = [calibrations1; calibrations2; calibrations3]
#    fitrfi_image_corrupted_models(spw, ms_path, meta, rfi, calibrations)
#    fitrfi_output(spw, meta, rfi1, calibrations)
#end
#
#function fitrfi_spw16(data, flags)
#    spw = 16
#    dadas = listdadas(spw)
#    ms, ms_path = dada2ms(dadas[1])
#    finalize(ms)
#
#    meta, visibilities0 = fitrfi_start(spw, data, flags, ms_path, checkpoint=true)
#
#    lat, lon, el = source_dictionary("A")
#    N = 2
#    rfi1, visibilities1, calibrations1 = fitrfi_do_source(spw, meta, visibilities0, ms_path,
#                                                          lat, lon, el, 1, N, checkpoint=true)
#
#    lat, lon, el = source_dictionary("B")
#    N = 2
#    rfi2, visibilities2, calibrations2 = fitrfi_do_source(spw, meta, visibilities1, ms_path,
#                                                          lat, lon, el, 2, N, checkpoint=true)
#
#    #lat, lon, el = source_dictionary("D")
#    #N = 2
#    #rfi3, visibilities3, calibrations3 = fitrfi_do_source(spw, meta, visibilities2, ms_path,
#    #                                                      lat, lon, el, 3, N, checkpoint=false)
#
#    fitrfi_image_corrupted_models(spw, ms_path, meta, [rfi1; rfi2], [calibrations1; calibrations2])
#    fitrfi_output(spw, meta, [rfi1; rfi2], [calibrations1; calibrations2])
#end

