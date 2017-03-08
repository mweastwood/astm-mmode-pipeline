function smeared_image(spw, filename="calibrated-visibilities"; minuvw=0)
    dir = getdir(spw)
    data, flags = load(joinpath(dir, filename*".jld"), "data", "flags")
    if ndims(data) == 2
        # if we want to image the folded dataset, the polarizations have been averaged together,
        # so we'll replicate the data for each polarization
        data = reshape(data, (1, size(data)...))
        data = vcat(data, data)
    end
    _, Nbase, Ntime = size(data)
    output = joinpath(dir, "smeared-"*filename)
    image(spw, data, flags, 1:Ntime, output, minuvw=minuvw)
end

function smeared_image_cas_a(spw, filename="calibrated-visibilities")
    dir = getdir(spw)
    times = load(joinpath(dir, "raw-visibilities.jld"), "times")
    data, flags = load(joinpath(dir, filename*".jld"), "data", "flags")
    _, Nbase, Ntime = size(data)
    output = joinpath(dir, "smeared-cas-a-"*filename)
    image_with_new_phase_center(spw, times, data, flags, 1:Ntime,
                                Direction(dir"J2000", "23h23m24s", "+58d48m54s"), output)
end

function smeared_image_cyg_a(spw, filename="calibrated-visibilities")
    dir = getdir(spw)
    times = load(joinpath(dir, "raw-visibilities.jld"), "times")
    data, flags = load(joinpath(dir, filename*".jld"), "data", "flags")
    _, Nbase, Ntime = size(data)
    output = joinpath(dir, "smeared-cyg-a-"*filename)
    image_with_new_phase_center(spw, times, data, flags, 1:Ntime,
                                Direction(dir"J2000", "19h59m28.35663s", "+40d44m02.0970s"), output)
end

"""
    image(spw, data, flags, range, image_path)

Create an image of the data integrated over the specified range of times.
"""
function image(spw, data, flags, range, image_path; minuvw=0)
    Nbase = size(data, 2)
    output = Visibilities(Nbase, 109)
    output.data[:] = zero(JonesMatrix)
    output.flags[:] = true
    for idx in range, α = 1:Nbase
        if !flags[α, idx]
            xx = data[1, α, idx]
            yy = data[2, α, idx]
            output.data[α, 55] += JonesMatrix(xx, 0, 0, yy)
            output.flags[α, 55] = false
        end
    end

    dadas = listdadas(spw)[range]
    ms, ms_path = dada2ms(dadas[1])
    TTCal.write(ms, "DATA", output)
    finalize(ms)
    wsclean(ms_path, image_path, j=8, minuvw=minuvw)
    rm(ms_path, recursive=true)
end

"""
    image_with_new_phase_center(spw, times, data, flags, range, phase_center, image_path)

Create an image of the data integrated over the specified range of times. However piror to imaging
the phase center is rotated to the specified direction.
"""
function image_with_new_phase_center(spw, times, data, flags, range, phase_center, image_path)
    meta = getmeta(spw)
    meta.channels = meta.channels[55:55]
    meta.phase_center = Direction(dir"AZEL", 0degrees, 90degrees)
    center = PointSource("phase center", phase_center, PowerLaw(1, 0, 0, 0, 1e6, [0.0]))

    Nbase = size(data, 2)
    output = Visibilities(Nbase, 109)
    output.data[:] = zero(JonesMatrix)
    output.flags[:] = true
    for idx in range
        meta.time = Epoch(epoch"UTC", times[idx]*seconds)
        frame = TTCal.reference_frame(meta)
        if TTCal.isabovehorizon(frame, center)
            model = genvis(meta, [center])
            for α = 1:Nbase
                if !flags[α, idx]
                    xx = data[1, α, idx]
                    yy = data[2, α, idx]
                    J = JonesMatrix(xx, 0, 0, yy)
                    J /= model.data[α, 1]
                    output.data[α, 55] += J
                    output.flags[α, 55] = false
                end
            end
        end
    end

    dadas = listdadas(spw)[range]
    ms, ms_path = dada2ms(dadas[1])
    TTCal.write(ms, "DATA", output)
    finalize(ms)
    wsclean(ms_path, image_path, j=8)
    rm(ms_path, recursive=true)
end

function image_mmodes(spw, target="mmodes-peeled", m=0)
    dir = getdir(spw)
    meta = getmeta(spw)
    mmodes, flags = load(joinpath(dir, target*".jld"), "blocks", "flags")
    block = mmodes[abs(m)+1]
    f = flags[abs(m)+1]

    output = Visibilities(Nbase(meta), 109)
    output.data[:] = zero(JonesMatrix)
    output.flags[:] = true
    for α1 = 1:Nbase(meta)
        if m > 0
            I = block[2α-1]
        elseif m < 0
            I = conj(block[2α-0])
        else # m == 0
            I = block[α]
        end
        if !f[α2]
            output.data[α1, 55] = JonesMatrix(I, 0, 0, I)
            output.flags[α1, 55] = false
        end
    end

    dadas = listdadas(spw)[1]
    ms, ms_path = dada2ms(dadas)
    TTCal.write(ms, "DATA", output)
    finalize(ms)
    image_path = joinpath(dir, "tmp", "image-$target-m=$m")
    wsclean(ms_path, image_path, j=8)
    rm(ms_path, recursive=true)
end

