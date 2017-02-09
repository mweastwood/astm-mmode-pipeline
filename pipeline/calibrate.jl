function calibrate(spw)
    dir = getdir(spw)
    input_path = joinpath(dir, "raw-visibilities.jld")
    times, phase, data = load(input_path, "times", "phase", "data")
    flags = flag!(spw, data)
    sawtooth = smooth_out_the_sawtooth!(data, flags)

    # save the intermediate data here while we try to figure out the calibration strategy
    save(joinpath(dir, "smoothed-and-flagged-visibilities.jld"),
         "data", data, "flags", flags, "sawtooth", sawtooth, compress=true)

end

"""
    flag!(spw, data)

Apply a set of a priori antenna and baseline flags. Additionally look for and flag extremely
egregious integrations.

This function will modify the input `data` by zero-ing out the flagged pieces.
"""
function flag!(spw, data)
    _, Nbase, Ntime = size(data)
    Nant = Nbase2Nant(Nbase)
    flags = zeros(Bool, Nbase, Ntime)

    # antenna flags
    files = ["coreflags_arxpickup.ants", "coreflags_gregg.ants", "coreflags_nosignal.ants",
             "expansionflags.ants", "ledaants.ants", "flagsRyan.ants", "flagsMarin.ants"]
    antennas = sort!(vcat(collect(read_antenna_flags(file) for file in files)...)) :: Vector{Int}
    if spw == 18
        antennas = [antennas; 59; 60; 61; 62; 63; 64] # see email sent 2017/02/07 12:18am
    end
    for ant1 in antennas, ant2 = 1:Nant
        if ant1 ≤ ant2
            α = baseline_index(ant1, ant2)
        else
            α = baseline_index(ant2, ant1)
        end
        flags[α, :] = true
        data[:, α, :] = 0
    end

    # baseline flags
    files = ["flagsRyan_adjacent.bl", "flagsRyan_score.bl", "flagsMarin.bl"]
    baselines = vcat(collect(read_baseline_flags(file) for file in files)...) :: Matrix{Int}
    for idx = 1:size(baselines, 1)
        ant1 = baselines[idx, 1]
        ant2 = baselines[idx, 2]
        α = baseline_index(ant1, ant2)
        flags[α, :] = true
        data[:, α, :] = 0
    end

    # integration flags
    do_integration_flags!(flags, data)

    flags
end

function do_integration_flags!(flags, data)
    _, Nbase, Ntime = size(data)
    Nant = Nbase2Nant(Nbase)

    autos = just_the_autos(data)
    auto_flags = just_the_auto_flags(flags)

    votes = zeros(Int, Ntime)
    total = zeros(Int, Ntime)
    for ant = 1:Nant, pol = 1:2
        myautos = autos[pol, ant, :]
        myflags = auto_flags[ant, :]
        all(myflags) && continue

        # Pass a median filter over the time series in order to smooth out any RFI spikes.
        width = 500
        median_filtered = zeros(Ntime)
        for t = 1:Ntime
            boxcar = -width÷2:width÷2
            boxcar = boxcar + t
            boxcar = max(1, boxcar[1]):min(Ntime, boxcar[end])
            median_filtered[t] = median(myautos[boxcar])
        end
        galaxy_subtracted = myautos - median_filtered

        # Use the median-absolute-deviation to test for bursts of RFI.
        mad = median(abs(galaxy_subtracted))
        cutoff = 10mad
        rfi = abs(galaxy_subtracted) .> cutoff
        votes[rfi] += 1
        total[:] += 1

        for idx = 1:Ntime
            if rfi[idx]
                for ant1 = 1:ant
                    α = baseline_index(ant1, ant)
                    flags[α, idx] = true
                    data[:, α, idx] = 0
                end
                for ant2 = ant+1:Nant
                    α = baseline_index(ant, ant2)
                    flags[α, idx] = true
                    data[:, α, idx] = 0
                end
            end
        end
    end

    for idx = 1:Ntime
        if votes[idx] / total[idx] > 0.05
            flags[:, idx] = true
            data[:, :, idx] = 0
        end
    end
end

function read_antenna_flags(filename)
    flags = readcsv(joinpath(workspace, "flags", filename), Int) + 1
    reshape(flags, length(flags))
end

function read_baseline_flags(filename)
    flags = readdlm(joinpath(workspace, "flags", filename), '&', Int) + 1
    flags
end

function read_channel_flags(filename, spw)
    flags = readdlm(joinpath(workspace, "flags", filename), ':', Int)
    keep = flags[:,1] .== spw
    flags[keep, 2] + 1
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

"""
    just_the_autos(data)

Returns a copy of the `data` that contains only the auto-correlations.
"""
function just_the_autos(data)
    _, Nbase, Ntime = size(data)
    Nant = Nbase2Nant(Nbase)
    idx = [baseline_index(ant, ant) for ant = 1:Nant]
    real(data[:, idx, :])
end

"""
    just_the_auto_flags(flags)

Returns a copy of `flags` that contains only the auto-correlation flags.
"""
function just_the_auto_flags(flags)
    Nbase, Ntime = size(flags)
    Nant = Nbase2Nant(Nbase)
    idx = [baseline_index(ant, ant) for ant = 1:Nant]
    flags[idx, :]
end

