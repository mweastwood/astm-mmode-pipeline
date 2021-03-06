function wiener(spw, dataset, target)
    if dataset == "rainy"
        spw ==  4 && (mrange = 0:1)
        spw ==  6 && (mrange = 0:1)
        spw ==  8 && (mrange = 0:1)
        spw == 10 && (mrange = 0:1)
        spw == 12 && (mrange = 0:1)
        spw == 14 && (mrange = 0:1)
        spw == 16 && (mrange = 0:1)
        spw == 18 && (mrange = 0:1)
    end

    dir = getdir(spw)
    alm, tolerance = load(joinpath(dir, "$target-$dataset.jld"), "alm", "tolerance")
    apply_wiener_filter!(alm, mrange)

    if contains(target, "odd")
        target = "alm-odd-wiener-filtered"
    elseif contains(target, "even")
        target = "alm-even-wiener-filtered"
    else
        if contains(target, "new")
            target = "new-alm-wiener-filtered"
        else
            target = "alm-wiener-filtered"
        end
    end
    save(joinpath(dir, "$target-$dataset.jld"),
         "alm", alm, "tolerance", tolerance, "mrange", mrange, compress=true)
end

function apply_wiener_filter!(alm, mrange)
    alm[0, 0] = 0
    for m in mrange
        if m == 0
            for l = 1:lmax(alm)
                alm[l, m] = 0
            end
        else
            for l = max(m, 100):lmax(alm)
                alm[l, m] = 0
            end
        end
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

