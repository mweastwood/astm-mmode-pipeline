module Driver

# Here we're going to smooth out the bandpass calibration and directly apply this updated
# calibration to the m-modes (so we can test out this idea without redoing too much work)

using JLD2
using ProgressMeter
using TTCal
using BPJSpec
using Unitful
using YAML

include("Project.jl")

struct Config
    input       :: String
    output      :: String
    input_calibration  :: String
    output_calibration :: String
    metadata    :: String
    hierarchy   :: String
    refant      :: Int # the reference antenna (we have just let the overall phase float until now)
    order       :: Int # order of the polynomial fit to the bandpass amplitude
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["input"],
           dict["output"],
           dict["input-calibration"],
           dict["output-calibration"],
           dict["metadata"],
           dict["hierarchy"],
           dict["refant"],
           dict["order"])
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    smooth(project, config)
end

function smooth(project, config)
    path = Project.workspace(project)
    metadata    = Project.load(project, config.metadata,    "metadata")
    hierarchy   = Project.load(project, config.hierarchy,   "hierarchy")
    calibration = Project.load(project, config.calibration, "calibration")
    input_calibration = cal_to_array(calibration, metadata, config.refant)
    output_calibration, coeff = _smooth(input_calibration, metadata, coeff)
    input_mmodes  = BPJSpec.load(joinpath(path, config.input))
    output_mmodes = simimlar(input_mmodes, MultipleFiles(joinpath(path, config.output)))
    correct_the_calibration!(output_mmodes, input_mmodes, output_calibration, input_calibration)
end

function _smooth(input, metadata, config)
    ν = metadata.frequencies
    coeff  = zeros(config.order + 4, 2, Nant(metadata))
    output = zeros(Complex128, Nfreq(metadata), 2, Nant(metadata))
    for ant = 1:Nant(metadata)
        coeff[:, 1, ant], output[:, 1, ant] = fit_bandpass(ν, @view(input[:, 1, ant]), config) # xx
        coeff[:, 2, ant], output[:, 2, ant] = fit_bandpass(ν, @view(input[:, 2, ant]), config) # yy
    end
    output, coeff
end

function cal_to_array(calibration, metadata, refant)
    # get the data into a format that is a little easier to work with
    output = zeros(Complex128, 2, Nant(metadata), Nfreq(metadata))
    for β = 1:Nfreq(metadata)
        cal = calibration[β, 1]
        for ant = 1:Nant(metadata)
            J = cal[ant]
            output[1, ant, β] = J.xx
            output[2, ant, β] = J.yy
        end
    end
    # fix the phase to the reference antenna
    for β = 1:Nfreq(metadata)
        xx_phase_factor = conj(output[1, refant, β]) / abs(output[1, refant, β])
        yy_phase_factor = conj(output[2, refant, β]) / abs(output[2, refant, β])
        output[1, :, β] .*= xx_phase_factor
        output[2, :, β] .*= yy_phase_factor
    end
    # put frequency on the fast axis
    output = permutedims(output, (3, 1, 2)) # Nfreq × Npol × Nant
end

function fit_bandpass(ν, gains, config)
    amplitude =   abs.(gains)
    phase     = angle.(gains)
    flags = isnan.(amplitude) .| (amplitude .== 0)
    νMHz  = ustrip.(uconvert.(u"MHz", ν))
    amplitude_coeff, amplitude_fit = fit_amplitude(νMHz, amplitude, flags, config.order)
    phase_coeff,     phase_fit     = fit_phase(νMHz, phase, flags)
    complete_coeff = [phase_coeff; amplitude_coeff]
    complete_fit   = amplitude_fit .* cis.(phase_fit)
    complete_coeff, complete_fit
end

function fit_amplitude(νMHz, amplitude, flags, order)
    polyfit(νMHz, amplitude, flags, order)
end

function fit_phase(νMHz, phase, flags)
    #  0 => phase offset relative to the reference antenna
    #  1 => delay term
    # -1 => differential total electron content (ie. relative to the reference antenna)
    # To get the delay in m, multiply by u"c / (2π*MHz)"
    # To get the TEC in TECU, divide by u"q^2 / (4pi*me*ϵ0*c) * (TECU/MHz)"
    polyfit(νMHz, unroll_phase(phase), flags, (0, 1, -1))
end

function polyfit(x, y, flags, order::Int)
    terms = collect(n for n = 0:order)
    polyfit(x, y, flags, terms)
end

function polyfit(x, y, flags, terms::Union{AbstractVector, Tuple})
    A = zeros(eltype(y), length(y), length(terms))
    for (jdx, n) in enumerate(terms)
        for idx = 1:length(y)
            A[idx, jdx] = x[idx]^n
        end
    end
    coeff  = A[.!flags, :] \ y[.!flags]
    values = A * coeff
    coeff, values
end

function unroll_phase(phase)
    unrolled_phase = copy(phase)
    for idx = 1:length(phase)-1
        Δϕ = phase[idx+1] - phase[idx]
        while Δϕ > π
            Δϕ -= 2π
        end
        while Δϕ < -π
            Δϕ += 2π
        end
        unrolled_phase[idx+1] = unrolled_phase[idx] + Δϕ
    end
    unrolled_phase
end

function correct_the_calibration!(output_mmodes,      input_mmodes,
                                  output_calibration, input_calibration,
                                  metadata, hierarchy)
    antenna1 = [ant1 for ant1 = 1:256 for ant2 = ant1:256]
    antenna2 = [ant2 for ant1 = 1:256 for ant2 = ant1:256]
    for β = 1:length(input_mmodes.frequencies), m = 0:input_mmodes.mmax
        block = input_mmodes[m, β]
        for (α, α′) in enumerate(baseline_permutation(hierarchy, m))
            ant1 = antenna1[α′]
            ant2 = antenna2[α′]
            # ah crap, the m-modes are summed in polarization
        end
    end
end

