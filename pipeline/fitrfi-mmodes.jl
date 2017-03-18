# Sometimes RFI components will make it past all of our defenses (`fitrfi` and `fitrfi_special`). At
# this point we will just fit and remove these components directly from the m-modes.


macro fitrfi_mmodes_start(spw, m)
    output = quote
        @fitrfi_preamble $spw

        meta = getmeta(spw)
        meta.channels = meta.channels[55:55]

        block = mmodes[abs($m)+1]
        flags = mmode_flags[abs($m)+1]
        if $m > 0
            block = block[1:2:end]
            flags = flags[1:2:end]
        elseif $m < 0
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
        #TTCal.flag_short_baselines!(visibilities, meta, 15.0)

        target = @sprintf("mmodes-peeled-m=%+05d", $m)
        fitrfi_image_visibilities(spw, ms_path, "fitrfi-start-"*target, meta, visibilities)
    end
    esc(output)
end

function reconstruct_mmodes(spw, mmodes, flags)
    dir = getdir(spw)
    #mmodes, flags = load(joinpath(dir, "mmodes-peeled.jld"), "blocks", "flags")

    m = 0
    path = joinpath(dir, "tmp", "updated-block-m=0.jld")
    if isfile(path)
        newblock = load(path, "block")
        mmodes[1] = newblock
    end

    for m = 1:10
        path = joinpath(dir, "tmp", "updated-block-m=$m.jld")
        if isfile(path)
            newblock = load(path, "block")
            mmodes[m+1][1:2:end] = newblock
        end
    end

    for m = -1:-1:-10
        path = joinpath(dir, "tmp", "updated-block-m=$m.jld")
        if isfile(path)
            newblock = load(path, "block")
            mmodes[abs(m)+1][1:2:end] = conj(newblock)
        end
    end

    save(joinpath(dir, "mmodes-cleaned.jld"), "blocks", mmodes, "flags", flags)
end

function fitrfi_spw18_mmodes(mmodes, mmode_flags)
    # new strategy:
    # * fit for the stationary correlated noise components with m=0
    # * scale and subtract these components from |m| ≤ 3
    @fitrfi_mmodes_start 18 0
    @fitrfi_construct_sources 5
    @fitrfi_peel_sources
    @fitrfi_finish

    # store the updated m=0 block
    block = getfield.(visibilities.data[:, 1], 1)
    mmodes[1] = block

    # now remove components from the other values of m
    components = copy(xx)
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

    save(joinpath(getdir(spw), "mmodes-cleaned-rainy.jld"), "blocks", mmodes, "flags", mmode_flags)
end



