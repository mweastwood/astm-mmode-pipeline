# Get the alm contribution for the subtracted RFI components

function getalm_rfi(spw, dataset, target)
    dir = getdir(spw)
    flags = load(joinpath(dir, "$target-$dataset-visibilities.jld"), "flags")
    xx_rfi, yy_rfi, xx_rfi_flux, yy_rfi_flux = load(joinpath(dir, "$target-$dataset-visibilities.jld"),
                                                    "xx-rfi", "yy-rfi", "xx-rfi-flux", "yy-rfi-flux")
    @time getalm_rfi(spw, flags, xx_rfi, yy_rfi, xx_rfi_flux, yy_rfi_flux, dataset, target)
end

function getalm_rfi(spw, flags, xx_rfi, yy_rfi, xx_rfi_flux, yy_rfi_flux, dataset, target)
    output = Alm[]
    for s = 1:size(xx_rfi, 2)
        @time alm = _getalm_rfi(spw, flags, xx_rfi[:, s], xx_rfi_flux[s, :], 1, dataset, target)
        push!(output, alm)
    end
    for s = 1:size(yy_rfi, 2)
        @time alm = _getalm_rfi(spw, flags, yy_rfi[:, s], yy_rfi_flux[s, :], 2, dataset, target)
        push!(output, alm)
    end

    dir = getdir(spw)
    output_filename = joinpath(dir, "alm-rfi-$target-$dataset.jld")
    save(output_filename, "alms", output, compress=true)
end

function _getalm_rfi(spw, flags, rfi, rfi_flux, polarization, dataset, target)
    Nbase = length(rfi)
    Ntime = length(rfi_flux)
    data = zeros(Complex128, 2, Nbase, Ntime)
    for idx = 1:Ntime, α = 1:Nbase
        data[polarization, α, idx] = rfi_flux[idx]*rfi[α]
    end

    println("Folding...")
    folded_data, folded_flags = _fold(spw, data, flags, dataset, target)
    println("Getting m-modes...")
    mmodes, mmode_flags = getmmodes_internal(folded_data, folded_flags)
    println("Getting alm...")
    alm = _getalm(spw, mmodes, mmode_flags)

    alm
end

