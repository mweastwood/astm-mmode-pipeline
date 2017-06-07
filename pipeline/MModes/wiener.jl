function wiener(spw, dataset, rfi_restored_target, rfi_subtracted_target)
    if dataset == "rainy"
        spw ==  4 && (mrange = 0:-1)
        spw ==  6 && (mrange = 0:-1)
        spw ==  8 && (mrange = 0:2)
        spw == 10 && (mrange = 0:2)
        spw == 12 && (mrange = 0:2)
        spw == 14 && (mrange = 0:2)
        spw == 16 && (mrange = 0:3)
        spw == 18 && (mrange = 0:2)
    end

    dir = getdir(spw)
    alm_rfi_restored = load(joinpath(dir, "$rfi_restored_target-$dataset.jld"), "alm")
    alm_rfi_subtracted, tolerance = load(joinpath(dir, "$rfi_subtracted_target-$dataset.jld"),
                                         "alm", "tolerance")
    alm_rfi = alm_rfi_restored - alm_rfi_subtracted

    output = deepcopy(alm_rfi_subtracted)
    if length(mrange) == 0
        # don't Wiener filter
        correction = zeros(lmax(output)+1)
    else
        # do Wiener filter
        signal = alm2Cl(alm_rfi_subtracted, mrange)
        contamination = alm2Cl(alm_rfi, mrange)
        correction = signal ./ (signal + contamination)
        correction[isnan(correction)] = 0
        apply_wiener_filter!(alm_rfi_restored, mrange, correction)
        for m in mrange, l = m:lmax(output)
            output[l, m] = alm_rfi_restored[l, m]
        end
    end

    save(joinpath(dir, "alm-wiener-filtered-$dataset.jld"),
         "alm", output, "tolerance", tolerance,
         "mrange", mrange, "correction", correction, compress=true)
end

function apply_wiener_filter!(alm, mrange, correction)
    for m in mrange, l = 0:lmax(alm)
        alm[l, m] *= correction[l+1]
    end
end

function alm2Cl(alm, mrange=0:mmax(alm))
    Cl = zeros(lmax(alm)+1)
    normalization = zeros(Int, lmax(alm)+1)
    for m in mrange, l = m:lmax(alm)
        Cl[l+1] += abs2(alm[l, m])
        normalization[l+1] += 1
    end
    Cl ./ normalization
end

function alm2image(alm)
    image = zeros(Complex128, lmax(alm)+1, mmax(alm)+1)
    for m = 0:mmax(alm), l = m:lmax(alm)
        image[l+1, m+1] = alm[l, m]
    end
    image
end

dB(x) = 10log10(abs(x))

