function getmmodes(spw, data, flags)
    mmax = 1000
    Nbase, Ntime = size(data)
    two(m) = ifelse(m != 0, 2, 1)
    blocks = [zeros(Complex128, two(m)*Nbase) for m = 0:mmax]
    fourier = do_fourier_transform(data)
    pack_mmodes!(blocks, fourier, mmax)
    block_flags = decide_on_baseline_flags(flags, mmax)
    save(joinpath(getdir(spw), "mmodes.jld"), "blocks", blocks, "flags", block_flags, compress=true)
    blocks, block_flags
end

function do_fourier_transform(data)
    Nbase, Ntime = size(data)
    FFTW.set_num_threads(16)
    transposed = permutedims(data, (2, 1)) # put time on the fast axis
    planned_fft = plan_fft(transposed, 1)
    fourier = planned_fft * transposed / Ntime
    permutedims(fourier, (2, 1)) # undo the previous transpose
end

function pack_mmodes!(blocks, fourier, mmax)
    Nbase, Ntime = size(fourier)
    for m = 0:mmax
        block = blocks[m+1]
        if m == 0
            for α = 1:Nbase
                block[α] = fourier[α, 1]
            end
        else
            for α = 1:Nbase
                α1 = 2α - 1 # positive m
                α2 = 2α - 0 # negative m
                block[α1] =      fourier[α, m+1]
                block[α2] = conj(fourier[α, Ntime+1-m])
            end
        end
    end
end

function decide_on_baseline_flags(flags, mmax)
    # a baseline will be flagged if it has any sidereal times that are flagged
    baseline_flags = squeeze(any(flags, 2), 2)
    Nbase = length(baseline_flags)
    block_flags = Vector{Bool}[]
    for m = 0:mmax
        if m == 0
            push!(block_flags, baseline_flags)
        else
            f = fill(false, 2Nbase)
            for α = 1:Nbase
                f[2α - 1] = baseline_flags[α]
                f[2α - 0] = baseline_flags[α]
            end
            push!(block_flags, f)
        end
    end
    block_flags
end

