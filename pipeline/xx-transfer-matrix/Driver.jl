module Driver

using BPJSpec
using CasaCore.Measures
using FileIO, JLD2
using TTCal

include("../lib/Common.jl"); using .Common

function transfermatrix(spw, name)
    path = getdir(spw, name)
    ttcal_metadata = load(joinpath(path, "raw-visibilities.jld2"), "metadata")
    frame = ReferenceFrame(ttcal_metadata)
    ttcal_metadata.phase_centers[1] = measure(frame, ttcal_metadata.phase_centers[1], dir"ITRF")
    bpjspec_metadata = BPJSpec.from_ttcal(ttcal_metadata)

    coeff = load("/lustre/mweastwood/mmode-analysis/workspace/spw18/beam.jld", "I-coeff")
    threshold = deg2rad(10)
    function beam_model(azimuth, elevation)
        beam(coeff, threshold, azimuth, elevation)
    end

    path = joinpath(path, "transfermatrix")
    transfermatrix = BPJSpec.HierarchicalTransferMatrix(path, bpjspec_metadata)
    BPJSpec.compute!(transfermatrix, beam_model, lmax=200)
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

end

