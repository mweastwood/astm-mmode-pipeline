module Driver

using ProgressMeter
using TTCal
using BPJSpec
using Unitful, UnitfulAstro
using YAML

#using UnicodePlots
using PyPlot
using PyCall
@pyimport matplotlib.pyplot as pyplot

include("Project.jl")
include("TTCalDatasets.jl")
using .TTCalDatasets

struct Config
    input       :: String
    metadata    :: String
    calibration :: String
    integration :: Int
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["input"],
           dict["metadata"],
           dict["calibration"],
           dict["integration"])
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    sefd(project, config)
end

function sefd(project, config)
    path = Project.workspace(project)
    input = BPJSpec.load(joinpath(path, config.input))
    metadata = Project.load(project, config.metadata, "metadata")
    ν = ustrip.(uconvert.(u"MHz", metadata.frequencies))

    Ω = 2.4u"sr"
    K = (u"c"/(ν[1]*u"MHz"))^2/(Ω*2u"k")

    # Mozdzen et al. 2017 report a measurement of the absolute sky flux in the southern hemisphere
    # between 90 and 190 MHz. The brightness temperature at 150 MHz varies between 842 K at 17 h
    # LST, and 257 K at 2 H LST. The spectral index fluctuates between -2.6 and -2.5. The spectral
    # index tends to flatten as the sky temperature increases (presumably due to free-free
    # absorption).
    high_temp = 842u"K" * (73/150)^-2.5
    low_temp  = 257u"K" * (73/150)^-2.6
    @show low_temp high_temp
    high_prediction = uconvert(u"Jy", high_temp/K)
    low_prediction  = uconvert(u"Jy", low_temp/K)
    lwa1_prediction = 256*4680u"Jy"
    lwa1_temp = 1740u"K"

    kelvin(x) = ustrip(uconvert(u"K",  x))
    jansky(x) = ustrip(uconvert(u"Jy", x))

    sefds = Vector{typeof(1.0u"Jy")}[]
    for integration = 10:500:6628
        V1 = input[integration-1]
        V2 = input[integration+0]
        V3 = input[integration+1]
        sefd = measure(V1, V2, V3)
        push!(sefds, sefd)
    end

    figure(1); clf()
    fill_between(ν,
                 fill(jansky( low_prediction)/1e6, length(ν)),
                 fill(jansky(high_prediction)/1e6, length(ν)),
                 facecolor="black", alpha=0.25)
    for sefd in sefds
        plot(ν[2:end-1], jansky.(sefd)/1e6, "k-", linewidth=1)
    end
    axhline(jansky(lwa1_prediction)/1e6, color="r", linestyle="-.", linewidth=1)
    axhline(jansky(high_prediction)/1e6, color="k", linestyle="--", linewidth=1)
    axhline(jansky( low_prediction)/1e6, color="k", linestyle="--", linewidth=1)
    xlabel("Frequency / MHz")
    ylabel("SEFD / MJy")
    xlim(ν[1], ν[end])

    figure(2); clf()
    fill_between(ν,
                 fill(kelvin( low_temp), length(ν)),
                 fill(kelvin(high_temp), length(ν)),
                 facecolor="black", alpha=0.25)
    for sefd in sefds
        plot(ν[2:end-1], kelvin.(K*sefd), "k-", linewidth=1)
    end
    axhline(kelvin(lwa1_temp), color="r", linestyle="-.", linewidth=1)
    axhline(kelvin(high_temp), color="k", linestyle="--", linewidth=1)
    axhline(kelvin( low_temp), color="k", linestyle="--", linewidth=1)
    xlabel("Frequency / MHz")
    ylabel("System Temperature / K")
    xlim(ν[1], ν[end])

    nothing
end

rms(X) = sqrt(mean(abs2.(X)))
rms(X, N) = squeeze(sqrt.(mean(abs2.(X), N)), N)

function difference_all(V1, V2, V3)
    _, Nfreq, Nbase = size(V1)
    output = zeros(Complex128, Nfreq-2, Nbase)
    for α = 1:Nbase, β = 2:Nfreq-1
        xx = 4V2[1, β, α] - (V1[1, β, α] + V3[1, β, α] + V2[1, β-1, α] + V2[1, β+1, α])
        yy = 4V2[2, β, α] - (V1[2, β, α] + V3[2, β, α] + V2[2, β-1, α] + V2[2, β+1, α])
        output[β-1, α] = (xx - yy) / 2
    end
    output ./ sqrt(10)
end

function measure(V1, V2, V3)
    f = squeeze(all(V1 .== 0, (1, 2)), (1, 2)) # flags
    # for just the real or imaginary component of the visibilities, you get an additional factor of
    # two here (ie. N = 2×Δν×τ)
    N = uconvert(NoUnits, 24u"kHz"*13u"s")
    Δall  = difference_all(V1, V2, V3) .* sqrt(N)
    rms(Δall[:, .!f], 2) .* u"Jy"
end

end

