function wiener(spw, dataset, rfi_restored_target, rfi_subtracted_target)
    mrange = 0:3

    dir = getdir(spw)
    alm_rfi_restored = load(joinpath(dir, "$rfi_restored_target-$dataset.jld"), "alm")
    alm_rfi_subtracted, tolerance = load(joinpath(dir, "$rfi_subtracted_target-$dataset.jld"),
                                         "alm", "tolerance")
    alm_rfi = alm_rfi_restored - alm_rfi_subtracted

    signal = alm2Cl(alm_rfi_subtracted, mrange)
    contamination = alm2Cl(alm_rfi, mrange)
    correction = signal ./ (signal + contamination)

    output = deepcopy(alm_rfi_subtracted)
    apply_wiener_filter!(alm_rfi_restored, correction)
    for m in mrange, l = m:lmax(output)
        output[l, m] = alm_rfi_restored[l, m]
    end

    save(joinpath(dir, "alm-wiener-filtered-$dataset.jld"),
         "alm", output, "tolerance", tolerance, "wiener-filtered", correction, compress=true)
end

function apply_wiener_filter!(alm, correction)
    for m = 0:3, l = 0:lmax(alm)
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

