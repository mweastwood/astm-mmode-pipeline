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
    times, data, flags = load(joinpath(dir, filename*".jld"), "times", "data", "flags")
    _, Nbase, Ntime = size(data)
    output = joinpath(dir, "smeared-cas-a-"*filename)
    image_with_new_phase_center(spw, times, data, flags, 1:Ntime,
                                Direction(dir"J2000", "23h23m24s", "+58d48m54s"), output)
end

function smeared_image_cyg_a(spw, filename="calibrated-visibilities")
    dir = getdir(spw)
    times, data, flags = load(joinpath(dir, filename*".jld"), "times", "data", "flags")
    _, Nbase, Ntime = size(data)
    output = joinpath(dir, "smeared-cyg-a-"*filename)
    image_with_new_phase_center(spw, times, data, flags, 1:Ntime,
                                Direction(dir"J2000", "19h59m28.35663s", "+40d44m02.0970s"), output)
end

const source_dictionary = Dict("Cyg A" => Direction(dir"J2000", "19h59m28.35663s", "+40d44m02.0970s"),
                               "Cas A" => Direction(dir"J2000", "23h23m24s", "58d48m54s"),
                               "Vir A" => Direction(dir"J2000", "12h30m49.42338s", "+12d23m28.0439s"),
                               "Tau A" => Direction(dir"J2000", "05h34m31.94s", "+22d00m52.2s"),
                               "Her A" => Direction(dir"J2000", "16h51m11.4s", "+04d59m20s"),
                               "Cen A" => Direction(dir"J2000", "13h25m27.61507s", "-43d01m08.8053s"),
                               "Sun"   => Direction(dir"SUN"))

function smeared_image_everything(spw, dataset, target)
    dir = getdir(spw)
    times, data, flags = load(joinpath(dir, "$target-$dataset-visibilities.jld"),
                              "times", "data", "flags")
    _, Nbase, Ntime = size(data)
    output = joinpath(dir, "smeared-$target-$dataset-visibilities")
    image(spw, data, flags, 1:Ntime, output)
    for name in keys(source_dictionary)
        direction = source_dictionary[name]
        output = joinpath(dir, "smeared-"*lowercase(replace(name, " ", "-"))*"-$target-$dataset-visibilities")
        image_with_new_phase_center(spw, times, data, flags, 1:Ntime, direction, output)
    end
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

    dadas = listdadas(spw, "100hr")[range]
    ms, ms_path = dada2ms(dadas[1], "100hr")
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
    meta = getmeta(spw, "rainy")
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

    dadas = listdadas(spw, "100hr")[range]
    ms, ms_path = dada2ms(dadas[1], "100hr")
    TTCal.write(ms, "DATA", output)
    finalize(ms)
    wsclean(ms_path, image_path, j=8)
    rm(ms_path, recursive=true)
end

function image_mmodes(spw, target="mmodes-peeled", m=0)
    dir = getdir(spw)
    meta = getmeta(spw, "rainy")
    mmodes, flags = load(joinpath(dir, target*".jld"), "blocks", "flags")
    block = mmodes[abs(m)+1]
    block_flags = flags[abs(m)+1]

    output = Visibilities(Nbase(meta), 109)
    output.data[:] = zero(JonesMatrix)
    output.flags[:] = true
    for α = 1:Nbase(meta)
        if m > 0
            I = block[2α-1]
            f = block_flags[2α-1]
        elseif m < 0
            I = conj(block[2α-0])
            f = block_flags[2α-0]
        else # m == 0
            I = block[α]
            f = block_flags[α]
        end
        if !f
            output.data[α, 55] = JonesMatrix(I, 0, 0, I)
            output.flags[α, 55] = false
        end
    end

    dadas = listdadas(spw, "100hr")[1]
    ms, ms_path = dada2ms(dadas, "100hr")
    TTCal.write(ms, "DATA", output)
    finalize(ms)
    image_path = joinpath(dir, "tmp", "image-$target-m=$m")
    wsclean(ms_path, image_path, j=8)
    rm(ms_path, recursive=true)
end

