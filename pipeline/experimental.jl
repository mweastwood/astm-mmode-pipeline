function experiment()
    spw = 18
    dir = getdir(spw)
    meta = getmeta(spw)
    meta.channels = meta.channels[55:55]

    # Let's try restoring the RFI to the visibilities before peeling them
    data, flags = load(joinpath(dir, "peeled-visibilities.jld"), "data", "flags")
    xx_rfi, yy_rfi = load(joinpath(dir, "calibrated-visibilities-rfi-components.jld"), "xx", "yy")
    xx_rfi_flux, yy_rfi_flux = load(joinpath(dir, "rfi-subtracted-calibrated-visibilities.jld"),
                                    "xx-rfi-flux", "yy-rfi-flux")
    restore_the_rfi(data, xx_rfi, yy_rfi, xx_rfi_flux, yy_rfi_flux)
    save(joinpath(dir, "rfi-restored-peeled-visibilities.jld"),
         "data", data, "flags", flags, compress=true)
end

function restore_the_rfi(data, xx_rfi, yy_rfi, xx_rfi_flux, yy_rfi_flux)
    _, Nbase, Ntime = size(data)
    Nrfi = size(xx_rfi, 2)
    for idx = 1:Ntime, s = 1:Nrfi, α = 1:Nbase
        data[1, α, idx] += xx_rfi_flux[s, idx]*xx_rfi[α, s]
        data[2, α, idx] += yy_rfi_flux[s, idx]*yy_rfi[α, s]
    end
end

function block_to_visibilities(block, block_flags)
    visibilities = Visibilities(length(block), 1)
    visibilities.flags[:] = true
    for α = 1:length(block)
        if !block_flags[α]
            xx = block[α]
            yy = block[α]
            visibilities.data[α, 1] = JonesMatrix(xx, 0, 0, yy)
            visibilities.flags[α, 1] = false
        end
    end
    visibilities
end

function visibilities_to_block(visibilities)
    block = getfield.(visibilities.data[:, 1], 1)
    block_flags = visibilities.flags[:, 1]
    block, block_flags
end

function block_to_square(block, block_flags)
    square = zeros(Complex128, 256, 256)
    for ant1 = 1:256, ant2 = ant1:256
        α = baseline_index(ant1, ant2)
        if !block_flags[α]
            if ant1 == ant2
                square[ant1, ant2] = real(block[α])
            else
                square[ant1, ant2] = block[α]
                square[ant2, ant1] = conj(square[ant1, ant2])
            end
        end
    end
    square
end

function square_to_block(square)
    block = zeros(Complex128, Nant2Nbase(256))
    for ant1 = 1:256, ant2 = ant1:256
        α = baseline_index(ant1, ant2)
        block[α] = square[ant1, ant2]
    end
    block
end

