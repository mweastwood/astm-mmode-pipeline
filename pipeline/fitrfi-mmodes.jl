# Sometimes RFI components will make it past all of our defenses (`fitrfi` and `fitrfi_special`). At
# this point we will just fit and remove these components directly from the m-modes.

function fitrfi_mmodes(spw, target)
    dir = getdir(spw)
    mmodes, flags = load(joinpath(dir, target*".jld"), "blocks", "flags")
    if spw == 4
        fitrfi_mmodes_spw04(mmodes, flags, target)
    elseif spw == 6
        fitrfi_mmodes_spw06(mmodes, flags, target)
    elseif spw == 8
        fitrfi_mmodes_spw08(mmodes, flags, target)
    elseif spw == 10
        fitrfi_mmodes_spw10(mmodes, flags, target)
    elseif spw == 12
        fitrfi_mmodes_spw12(mmodes, flags, target)
    elseif spw == 14
        fitrfi_mmodes_spw14(mmodes, flags, target)
    elseif spw == 16
        fitrfi_mmodes_spw16(mmodes, flags, target)
    elseif spw == 18
        fitrfi_mmodes_spw18(mmodes, flags, target)
    end
    nothing
end


macro fitrfi_mmodes_start(spw, m)
    output = quote
        @fitrfi_preamble $spw
        m = $m

        meta = getmeta(spw)
        meta.channels = meta.channels[55:55]

        block = mmodes[abs(m)+1]
        flags = mmode_flags[abs(m)+1]
        if m > 0
            block = block[1:2:end]
            flags = flags[1:2:end]
        elseif m < 0
            block = conj(block[2:2:end])
            flags = flags[2:2:end]
        end

        Nbase = length(block)
        visibilities = Visibilities(Nbase, 1)
        visibilities.flags[:] = true
        for α = 1:Nbase
            if !flags[α]
                xx = block[α]
                yy = block[α]
                visibilities.data[α, 1] = JonesMatrix(xx, 0, 0, yy)
                visibilities.flags[α, 1] = false
            end
        end
        TTCal.flag_short_baselines!(visibilities, meta, 15.0)

        _target = target*@sprintf("-m=%+05d", m)
        fitrfi_image_visibilities(spw, ms_path, "fitrfi-start-"*_target, meta, visibilities)
    end
    esc(output)
end

macro fitrfi_mmodes_finish()
    output = quote
        fitrfi_image_corrupted_models(spw, ms_path, meta, sources, calibrations, target)
        fitrfi_image_visibilities(spw, ms_path, "fitrfi-finish-"*_target, meta, visibilities)
        if m > 0
            mmodes[abs(m)+1][1:2:end] = getfield.(visibilities.data[:, 1], 1)
        elseif m < 0
            mmodes[abs(m)+1][2:2:end] = conj(getfield.(visibilities.data[:, 1], 1))
        else # m == 0
            mmodes[abs(m)+1] = getfield.(visibilities.data[:, 1], 1)
        end
    end
    esc(output)
end

function subtract_from_other_mmodes!(mmodes, mmode_flags, components)
    # m = 0
    m = 0
    v = mmodes[1]
    f = mmode_flags[1]
    v_flagged = v[!f]
    matrix = components[!f, :]
    coeff = matrix \ v_flagged
    v_flagged -= matrix*coeff
    v[!f] = v_flagged
    @show m,coeff

    for m = 1:10
        block = mmodes[m+1]
        flags = mmode_flags[m+1]

        # +m
        v = @view block[1:2:end]
        f = flags[1:2:end]
        v_flagged = v[!f]
        matrix = components[!f, :]
        coeff = matrix \ v_flagged
        v_flagged -= matrix*coeff
        v[!f] = v_flagged
        @show +m,coeff

        # -m
        v = @view block[2:2:end]
        f = flags[2:2:end]
        v_flagged = conj(v[!f])
        matrix = components[!f, :]
        coeff = matrix \ v_flagged
        v_flagged -= matrix*coeff
        v[!f] = conj(v_flagged)
        @show -m,coeff
    end
end

function fitrfi_mmodes_spw04(mmodes, mmode_flags, target)
    save(joinpath(getdir(spw), "mmodes-cleaned-rainy.jld"), "blocks", mmodes, "flags", mmode_flags)
end

function fitrfi_mmodes_spw06(mmodes, mmode_flags, target)
    save(joinpath(getdir(spw), "mmodes-cleaned-rainy.jld"), "blocks", mmodes, "flags", mmode_flags)
end

function fitrfi_mmodes_spw08(mmodes, mmode_flags, target)
    save(joinpath(getdir(spw), "mmodes-cleaned-rainy.jld"), "blocks", mmodes, "flags", mmode_flags)
end

function fitrfi_mmodes_spw10(mmodes, mmode_flags, target)
    save(joinpath(getdir(spw), "mmodes-cleaned-rainy.jld"), "blocks", mmodes, "flags", mmode_flags)
end

function fitrfi_mmodes_spw12(mmodes, mmode_flags, target)
    save(joinpath(getdir(spw), "mmodes-cleaned-rainy.jld"), "blocks", mmodes, "flags", mmode_flags)
end

function fitrfi_mmodes_spw14(mmodes, mmode_flags, target)
    save(joinpath(getdir(spw), "mmodes-cleaned-rainy.jld"), "blocks", mmodes, "flags", mmode_flags)
end

function fitrfi_mmodes_spw16(mmodes, mmode_flags, target)
    save(joinpath(getdir(spw), "mmodes-cleaned-rainy.jld"), "blocks", mmodes, "flags", mmode_flags)
end

function fitrfi_mmodes_spw18(mmodes, mmode_flags, target)
    if target == "mmodes-peeled-rainy"
        @fitrfi_mmodes_start 18 1
        @fitrfi_construct_sources 2
        @fitrfi_peel_sources
        @fitrfi_mmodes_finish

        @fitrfi_mmodes_start 18 -1
        @fitrfi_construct_sources 2
        @fitrfi_peel_sources
        @fitrfi_mmodes_finish
    end
    save(joinpath(getdir(spw), "mmodes-cleaned-rainy.jld"), "blocks", mmodes, "flags", mmode_flags)
end

