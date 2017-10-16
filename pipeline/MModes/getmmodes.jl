function getmmodes(spw, dataset, target; mmax=1000)
    dir = getdir(spw)
    data, flags = load(joinpath(dir, "$target-$dataset-visibilities.jld"), "data", "flags")
    getmmodes(spw, data, flags, dataset, target, mmax=mmax)
end

function getmmodes(spw, data, flags, dataset, target, dϕ=0.0; mmax=1000)
    blocks, block_flags = getmmodes_internal(data, flags, dϕ, mmax=mmax)
    target = replace(target, "folded-", "")
    save(joinpath(getdir(spw), "mmodes-$target-$dataset.jld"),
         "blocks", blocks, "flags", block_flags, compress=true)
    blocks, block_flags
end

function getmmodes_internal(data, flags, dϕ=0.0; mmax=1000)
    Nbase, Ntime = size(data)
    two(m) = ifelse(m != 0, 2, 1)
    blocks = [zeros(Complex128, two(m)*Nbase) for m = 0:mmax]
    fourier = do_fourier_transform(data)
    pack_mmodes!(blocks, fourier, mmax, dϕ)
    block_flags = decide_on_baseline_flags(flags, mmax)
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

function pack_mmodes!(blocks, fourier, mmax, dϕ)
    Nbase, Ntime = size(fourier)
    for m = 0:mmax
        block = blocks[m+1]
        if m == 0
            for α = 1:Nbase
                block[α] = fourier[α, 1]
            end
        else
            rotation = cis(m*dϕ)
            for α = 1:Nbase
                α1 = 2α - 1 # positive m
                α2 = 2α - 0 # negative m
                block[α1] =      fourier[α, m+1] * rotation
                block[α2] = conj(fourier[α, Ntime+1-m]) * rotation
            end
        end
    end
end

function decide_on_baseline_flags(flags, mmax)
    # a baseline will be flagged if it has any sidereal times that are flagged
    #baseline_flags = squeeze(any(flags, 2), 2)
    baseline_flags = squeeze(all(flags, 2), 2)
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

# ODD INTEGRATIONS ONLY

function getmmodes_odd(spw, dataset, target)
    dir = getdir(spw)
    data, flags = load(joinpath(dir, "$target-$dataset-visibilities.jld"), "data", "flags")
    data  =  data[:, 1:2:end]
    flags = flags[:, 1:2:end]
    target = "odd-"*target
    getmmodes(spw, data, flags, dataset, target)
end

# EVEN INTEGRATIONS ONLY

function getmmodes_even(spw, dataset, target)
    dir = getdir(spw)
    data, flags = load(joinpath(dir, "$target-$dataset-visibilities.jld"), "data", "flags")
    data  =  data[:, 2:2:end]
    flags = flags[:, 2:2:end]
    target = "even-"*target
    getmmodes(spw, data, flags, dataset, target, -2π/6628)
end

