function sawtooth(spw, dataset, target)
    dir = getdir(spw)
    times, data, flags = load(joinpath(dir, "$target-$dataset-visibilities.jld"), "times", "data", "flags")
    sawtooth = smooth_out_the_sawtooth!(data, flags)
    output = joinpath(dir, "smoothed-$target-$dataset-visibilities.jld")
    isfile(output) && rm(output)
    save(output, "times", times, "data", data, "flags", flags, "sawtooth", sawtooth, compress=true)
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
    sawtooth = get_the_sawtooth(autos, auto_flags)
    apply_the_sawtooth_correction!(data, flags, sawtooth)
    sawtooth
end

function get_the_sawtooth(autos, auto_flags)
    _, Nant, Ntime = size(autos)
    sawtooth = zeros(2, Nant, Ntime)
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
                sawtooth[pol, ant, t] = myautos[t] / smoothed[t]
            end
        end
    end

    sawtooth
end

function apply_the_sawtooth_correction!(data, flags, sawtooth)
    _, Nbase, Ntime = size(data)
    Nant = Nbase2Nant(Nbase)
    for t = 1:Ntime
        for ant1 = 1:Nant, ant2 = ant1:Nant
            α = baseline_index(ant1, ant2)
            if !flags[α, t]
                if ant1 == ant2
                    data[1, α, t] /= sawtooth[1, ant1, t]
                    data[2, α, t] /= sawtooth[2, ant1, t]
                else
                    data[1, α, t] /= sqrt(sawtooth[1, ant1, t]) * sqrt(sawtooth[1, ant2, t])
                    data[2, α, t] /= sqrt(sawtooth[2, ant1, t]) * sqrt(sawtooth[2, ant2, t])
                end
            end
        end
    end
end

