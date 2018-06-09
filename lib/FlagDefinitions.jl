module FlagDefinitions

export Flags
export flag_baseline!, flag_channel!, flag_integration!
export flag_baseline_channel!, flag_baseline_integration!, flag_baseline_channel_integration!

struct Flags
    # A full matrix of (baseline, channel, integration) flags is actually enormous if we are using a
    # full byte to store a `Bool` per visibility. However, we can instead use a `BitArray`. This
    # uses much less memory (generally 8 times less), but is usually slower to index. This is a
    # worthwhile tradeoff to allow us to generally represent any combination of flags we want.
    bits :: BitArray{3} # Nbase × Nfreq × Ntime
    # We would also like to maintain a record of the measured RMS after channel differencing, so
    # that we can use this information to re-flag the dataset in later steps without needing to take
    # transposes of the visibilities.
    channel_difference_rms :: Vector{Float64}
    # A (Ntime × Nfreq × Nant) matrix of the sawtooth pattern for each antenna.
    sawtooth :: Array{Float64, 3}
end

function Flags(metadata::TTCal.Metadata)
    bits = BitArray(Nbase(metadata), Nfreq(metadata), Ntime(metadata))
    bits[:] = false
    channel_difference_rms = zeros(Nfreq(metadata)-2)
    sawtooth = zeros(Ntime(metadata), Nfreq(metadata), Nant(metadata))
    Flags(bits, channel_difference_rms, sawtooth)
end

flag_baseline!(flags::Flags, baseline) = flags.bits[baseline, :, :] = true
flag_channel!(flags::Flags, channel) = flags.bits[:, channel, :] = true
flag_integration!(flags::Flags, integration) = flags.bits[:, :, integration] = true
flag_baseline_channel!(flags::Flags, baseline, channel) =
    flags.bits[baseline, channel, :] = true
flag_baseline_integration!(flags::Flags, baseline, integration) =
    flags.bits[baseline, :, integration] = true
flag_baseline_channel_integration!(flags::Flags, baseline, channel, integration) =
    flags.bits[baseline, channel, integration] = true

end

