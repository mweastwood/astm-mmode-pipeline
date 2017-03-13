function experiment()
    spw = 18
    dir = getdir(spw)
    meta = getmeta(spw)
    meta.channels = meta.channels[55:55]
    mmodes = load(joinpath(dir, "mmodes-peeled.jld"), "blocks")
    block = mmodes[1]
    integration_flags = load(joinpath(dir, "calibrated-visibilities.jld"), "flags")
    block_flags = squeeze(all(integration_flags, 2), 2)

    #visibilities = block_to_visibilities(block, block_flags)
    #TTCal.flag_short_baselines!(visibilities, meta, 15.0)
    #@fitrfi_construct_sources 20
    #peel!(visibilities, meta, ConstantBeam(), sources, peeliter=10, maxiter=200, tolerance=1e-5)
    #block, block_flags = visibilities_to_block(visibilities)

    square = block_to_square(block, block_flags)
    D, V = eig(Hermitian(square))

    transfermatrix = TransferMatrix(joinpath(dir, "transfermatrix"))
    B = transfermatrix[0, 1]

    answers = zeros(256)
    for component = 1:256
        myD = copy(D)
        myD[component] = 0
        myD[253] = 0
        myD[251] = 0
        myD[235] = 0
        myD[255] = 0
        myD[241] = 0
        #myD[237] = 0
        #myD[55] = 0
        square = V*diagm(myD)*V'
        block = square_to_block(square)
        a = tikhonov(B[!block_flags, :], block[!block_flags], 1e-2)
        res = sum(abs2(a[100:end])) |> sqrt
        @show component, res
        answers[component] = res
    end
    components = sortperm(answers)
    for idx = 1:10
        @show components[idx] answers[components[idx]]
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

