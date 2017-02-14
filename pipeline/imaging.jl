"""
    image(spw, data, flags, range, image_path)

Create an image of the data integrated over the specified range of times.
"""
function image(spw, data, flags, range, image_path)
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
    wsclean(ms_path, image_path, j=8)
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

