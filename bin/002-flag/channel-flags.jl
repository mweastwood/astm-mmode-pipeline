function apply_channel_flags!(data, flags)
    Nbase, Nfreq = size(data)
    prg = Progress(Nbase)
    for α = 1:Nbase
        spectrum = data[α, :]
        if !(all(spectrum .== 0))
            flags.channel_flags[α, :] = flag_channels(spectrum)
        end
        next!(prg)
    end
    flags
end

#using PyPlot

function flag_channels(spectrum)
    N = length(spectrum)
    e = ones(N)
    x = collect(1:N)
    y = abs.(spectrum)
    A = [x e]
    c = A\y
    z = A*c
    δ = z-y
    σ = std(δ)
    flags = δ .> 3σ

    #figure(1); clf()
    #plot(1:N, y, "k-")
    #plot(1:N, z, "k--")
    #plot(1:N, z+10σ, "r--")

    flags
end

