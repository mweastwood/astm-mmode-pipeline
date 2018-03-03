function gettransfermatrix(spw, dataset)
    dir = getdir(spw)
    ttcal_metadata = getmeta(spw, dataset)
    frame = TTCal.reference_frame(ttcal_metadata)
    ttcal_metadata.phase_center = measure(frame, ttcal_metadata.phase_center, dir"ITRF")
    bpjspec_metadata = BPJSpec.from_ttcal(ttcal_metadata)

    coeff = load("/lustre/mweastwood/mmode-analysis/workspace/spw18/beam.jld", "I-coeff")
    threshold = deg2rad(10)
    function beam_model(azimuth, elevation)
        beam(coeff, threshold, azimuth, elevation)
    end

    path = joinpath(dir, "transfermatrix")
    transfermatrix = BPJSpec.HierarchicalTransferMatrix(path, bpjspec_metadata, beam_model)
    BPJSpec.compute!(transfermatrix)
end

function beam(coeff, threshold, azimuth, elevation)
    elevation < 0 && return 0.0
    ρ = cos(elevation)
    θ = azimuth
    amplitude = (coeff[1]*TTCal.zernike(0, 0, ρ, θ)
                + coeff[2]*TTCal.zernike(2, 0, ρ, θ)
                + coeff[3]*TTCal.zernike(4, 0, ρ, θ)
                + coeff[4]*TTCal.zernike(4, 4, ρ, θ)
                + coeff[5]*TTCal.zernike(6, 0, ρ, θ)
                + coeff[6]*TTCal.zernike(6, 4, ρ, θ)
                + coeff[7]*TTCal.zernike(8, 0, ρ, θ)
                + coeff[8]*TTCal.zernike(8, 4, ρ, θ)
                + coeff[9]*TTCal.zernike(8, 8, ρ, θ))
    if elevation < threshold
        # Shaping function from http://www.flong.com/texts/code/shapers_poly/
        x = elevation/threshold
        shape = 4/9*x^6 - 17/9*x^4 + 22/9*x^2
        amplitude *= shape
    end
    amplitude
end

