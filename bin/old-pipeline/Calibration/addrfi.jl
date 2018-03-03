function addrfi(spw, dataset, target, rfi_target)
    dir = getdir(spw)
    times, data, flags = load(joinpath(dir, "$target-$dataset-visibilities.jld"),
                              "times", "data", "flags")
    xx_rfi, yy_rfi, xx_rfi_flux, yy_rfi_flux = load(joinpath(dir, "$rfi_target-$dataset-visibilities.jld"),
                                                    "xx-rfi", "yy-rfi", "xx-rfi-flux", "yy-rfi-flux")
    addrfi(spw, times, data, flags, xx_rfi, yy_rfi, xx_rfi_flux, yy_rfi_flux, dataset, target)
end

function addrfi(spw, times, data, flags, xx_rfi, yy_rfi, xx_rfi_flux, yy_rfi_flux, dataset, target)
    _addrfi(spw, data, xx_rfi, yy_rfi, xx_rfi_flux, yy_rfi_flux)

    dir = getdir(spw)
    output_file = joinpath(dir, "rfi-restored-$target-$dataset-visibilities.jld")
    isfile(output_file) && rm(output_file)
    save(output_file, "times", times, "data", data, "flags", flags,
         "xx-rfi", xx_rfi, "yy-rfi", yy_rfi,
         "xx-rfi-flux", xx_rfi_flux, "yy-rfi-flux", yy_rfi_flux, compress=true)

    data, flags
end

function _addrfi(spw, data, xx_rfi, yy_rfi, xx_rfi_flux, yy_rfi_flux)
    _, Ntime = size(xx_rfi_flux)
    Nbase = size(xx_rfi, 1)
    for idx = 1:Ntime
        for s = 1:size(xx_rfi_flux, 1), α = 1:Nbase
            data[1, α, idx] += xx_rfi_flux[s, idx]*xx_rfi[α, s]
        end
        for s = 1:size(yy_rfi_flux, 1), α = 1:Nbase
            data[2, α, idx] += yy_rfi_flux[s, idx]*yy_rfi[α, s]
        end
    end
    data
end

