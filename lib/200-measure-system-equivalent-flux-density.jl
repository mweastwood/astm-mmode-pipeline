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
include("WSClean.jl")
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

function go(project_file, wsclean_file, config_file)
    project = Project.load(project_file)
    wsclean = WSClean.load(wsclean_file)
    config  = load(config_file)
    sefd(project, wsclean, config)
end

function sefd(project, wsclean, config)
    path = Project.workspace(project)
    input = BPJSpec.load(joinpath(path, config.input))
    metadata = Project.load(project, config.metadata, "metadata")
    ν = ustrip.(uconvert.(u"MHz", metadata.frequencies))

    # Mozdzen et al. 2017 report a measurement of the absolute sky flux in the southern hemisphere
    # between 90 and 190 MHz. The brightness temperature at 150 MHz varies between 842 K at 17 h
    # LST, and 257 K at 2 H LST. The spectral index fluctuates between -2.6 and -2.5. The spectral
    # index tends to flatten as the sky temperature increases (presumably due to free-free
    # absorption).
    high_temp = 842u"K" * (73/150)^-2.5
    low_temp  = 257u"K" * (73/150)^-2.6
    high_prediction = uconvert(u"Jy", 2u"k"*high_temp*(2.41u"sr")*(73u"MHz")^2/(u"c^2"))
    low_prediction  = uconvert(u"Jy", 2u"k"* low_temp*(2.41u"sr")*(73u"MHz")^2/(u"c^2"))
    lwa1_prediction = 256*4680u"Jy"

    #V1 = input[config.integration-1]
    #V2 = input[config.integration+0]
    #V3 = input[config.integration+1]
    #differences(V1, V2, V3)

    figure(1); clf()
    fill_between(ν,
                 fill(ustrip( low_prediction)/1e6, length(ν)),
                 fill(ustrip(high_prediction)/1e6, length(ν)),
                 facecolor="black", alpha=0.25)
    axhline(ustrip(lwa1_prediction)/1e6, color="k", linestyle="-.", linewidth=1)
    axhline(ustrip(high_prediction)/1e6, color="k", linestyle="--", linewidth=1)
    axhline(ustrip( low_prediction)/1e6, color="k", linestyle="--", linewidth=1)
    for integration = 10:500:6628
        V1 = input[integration-1]
        V2 = input[integration+0]
        V3 = input[integration+1]
        sefd = differences(V1, V2, V3)./1e6
        plot(ν[2:end-1], sefd, "k-", linewidth=1)
    end

    xlabel("Frequency / MHz")
    ylabel("SEFD / MJy")
    xlim(ν[1], ν[end])
end

rms(X) = sqrt(mean(abs2.(X)))
rms(X, N) = sqrt.(mean(abs2.(X), N))
mad(X) = median(abs.(X))
mad(X, N) = median(abs.(X), N)

difference_time(V1, V2, V3) = @. V1 - (V2 + V3)/2
difference_freq(V) = V[:, 2:end-1, :] - (V[:, 1:end-2, :] + V[:, 3:end, :])/2
difference_pol(V) = @. (V[1, :, :] - V[2, :, :])/2

function difference_all(V1, V2, V3)
    _, Nfreq, Nbase = size(V1)
    output = zeros(Complex128, Nfreq-2, Nbase)
    for α = 1:Nbase, β = 2:Nfreq-1
        xx = V2[1, β, α] - (V1[1, β, α] + V3[1, β, α] + V2[1, β-1, α] + V2[1, β+1, α])/4
        yy = V2[2, β, α] - (V1[2, β, α] + V3[2, β, α] + V2[2, β-1, α] + V2[2, β+1, α])/4
        output[β-1, α] = (xx - yy)/2
    end
    output
end

function differences(V1, V2, V3)
    f = squeeze(all(V1 .== 0, (1, 2)), (1, 2)) # flags
    N = uconvert(NoUnits, 2*24u"kHz"*13u"s")

    #Δt    = difference_time(V1, V2, V3)
    #Δf1   = difference_freq(V1)
    #Δf2   = difference_freq(V1)
    #Δf3   = difference_freq(V1)
    #Δpol1 = difference_pol(V1)
    #Δpol2 = difference_pol(V2)
    #Δpol3 = difference_pol(V3)
    Δall  = difference_all(V1, V2, V3) .* sqrt(N) ./ sqrt(5/8)

    #figure(1); clf()
    #semilogy(1:107, rms(   V2[1, :, .!f], 2).*sqrt(N), "k-")
    #semilogy(1:107, rms(   Δt[1, :, .!f], 2).*sqrt(N)./sqrt(3), "r-")
    #semilogy(2:106, rms(  Δf2[1, :, .!f], 2).*sqrt(N)./sqrt(3), "g-")
    #semilogy(1:107, rms(Δpol2[   :, .!f], 2).*sqrt(N), "b-")
    #semilogy(2:106, rms( Δall[   :, .!f], 2), "k-")
    #semilogy(2:106, mad( Δall[   :, .!f], 2), "r-")

    #for scale = 1.0:0.1:2.0
    #    axhline(ustrip(scale.*prediction), color="k", linestyle="--")
    #end

    #figure(1); clf()
    #samples = vec(abs.(Δall[:, .!f]))
    #pyplot.hist(samples, bins=linspace(0, 10e6), histtype="step", label="data")
    #tight_layout()

    #@show rms(samples)
    #@show mad(samples)

    #test = abs.(complex.(randn(length(samples)), randn(length(samples)))) * rms(samples) / √2
    #pyplot.hist(test, bins=linspace(0, 10e6), histtype="step", label="rms")
    #test = abs.(complex.(randn(length(samples)), randn(length(samples)))) * mad(samples) / √2
    #pyplot.hist(test, bins=linspace(0, 10e6), histtype="step", label="mad")
    #legend()

    rms(Δall[:, .!f], 2)
end

end

