function sawtooth(spw)
    dir = getdir(spw)
    times, phase, data = load(joinpath(dir, "raw-visibilities.jld"), "times", "phase", "data")

    flags = flag!(spw, data)
    sawtooth = smooth_out_the_sawtooth!(data, flags)

    # save the intermediate result for later analysis
    save(joinpath(dir, "smoothed-visibilities.jld"),
         "data", data, "flags", flags, "sawtooth", sawtooth, compress=true)

    nothing
end

"""
    smooth_out_the_sawtooth!(data, flags)

The AC unit in the electronics shelter seems to turn off every 15 minutes or so. This leads to
gain variations on 15 minute timescales that manifests as a sawtooth pattern in the gains.

The timescale of the sawtooth pattern seems to vary throughout the day, making a global fit
difficult, but we can exploit the fact the pattern is the same in every single antenna to get an
empirical measure.
"""
function smooth_out_the_sawtooth!(data, flags)
    autos = just_the_autos(data)
    auto_flags = just_the_auto_flags(flags)
    _, Nant, Ntime = size(autos)
    Nbase = size(data, 2)

    sawtooth = zeros(Ntime)
    sawtooth_normalization = zeros(Int, Ntime)
    for ant = 1:Nant, pol = 1:2
        myautos = autos[pol, ant, :]
        myflags = auto_flags[ant, :]
        all(myflags) && continue

        # Pass a Gaussian convolution kernel over the time series in order to smooth out the
        # sawtooth pattern.
        width = 200
        kernel = exp(-0.5 * (linspace(-3, 3, width+1)).^2)
        convolved = zeros(Ntime)
        convolved_normalization = zeros(Ntime)
        for t1 = 1:Ntime
            range = -width÷2:width÷2
            range += t1
            range = max(1, range[1]):min(Ntime, range[end])
            for t2 in range
                if !myflags[t2]
                    idx = t2 - t1 + width÷2 + 1
                    convolved[t1] += myautos[t2] * kernel[idx]
                    convolved_normalization[t1] += kernel[idx]
                end
            end
        end
        smoothed = convolved ./ convolved_normalization

        # Divide by the smoothed component to pick out the gain fluctuations.
        for t = 1:Ntime
            if !myflags[t]
                sawtooth[t] += myautos[t] / smoothed[t]
                sawtooth_normalization[t] += 1
            end
        end
    end
    sawtooth ./= sawtooth_normalization

    for t = 1:Ntime, α = 1:Nbase
        if !flags[α, t]
            data[1, α, t] /= sawtooth[t]
            data[2, α, t] /= sawtooth[t]
        end
    end

    sawtooth
end

