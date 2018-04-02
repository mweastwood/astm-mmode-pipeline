#!/usr/bin/env julia-0.6

using ArgParse
using FileIO, JLD2
using TTCal
using PyCall, PyPlot
using ProgressMeter
@pyimport matplotlib.backends.backend_pdf as Pdf

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table s begin
        "input"
            help = "path to the calibration"
            arg_type = String
            required = true
        "output"
            help = "path to the output pdf"
            arg_type = String
            required = true
        "reference-antenna"
            help = "the reference antenna (phase of x and y set to zero)"
            arg_type = Int
            required = true
    end
    return parse_args(s)
end

function extract_xx_yy(calibration, reference)
    xx = zeros(Complex128, Nfreq(calibration), 256)
    yy = zeros(Complex128, Nfreq(calibration), 256)
    for β = 1:Nfreq(calibration), ant = 1:256
        J = calibration[β, 1][ant]
        xx[β, ant] = J.xx
        yy[β, ant] = J.yy
    end
    xx .*= conj.(xx[:, reference])./abs.(xx[:, reference])
    yy .*= conj.(yy[:, reference])./abs.(yy[:, reference])
    xx, yy
end

function circles()
    θ = linspace(0, 2π)
    plot(10 .* sin.(θ), 10 .* cos.(θ), "k-", alpha=0.5)
    plot(20 .* sin.(θ), 20 .* cos.(θ), "k-", alpha=0.5)
    plot(30 .* sin.(θ), 30 .* cos.(θ), "k-", alpha=0.5)
end

function create_plot(output, xx, yy)
    @pywith Pdf.PdfPages(output) as pdf begin
        prg = Progress(256)
        ants = 1:8
        for arx = 1:32
            figure(figsize=(16, 8))
            for (idx, ant) in enumerate(ants)
                subplot(2, 4, idx)
                circles()
                plot(real.(xx[:, ant]), imag.(xx[:, ant]), "r-")
                plot(real.(yy[:, ant]), imag.(yy[:, ant]), "b-")
                gca()[:set_aspect]("equal")
                xlabel("real(gain)")
                ylabel("imag(gain)")
                xlim(-35, 35)
                ylim(-35, 35)
                title(@sprintf("ant%03d", ant))
                next!(prg)
            end
            ants += 8
            tight_layout()
            pdf[:savefig]()
            close()
        end
    end
end

function main()
    args = parse_commandline()
    calibration = load(args["input"], "calibration")
    xx, yy = extract_xx_yy(calibration, args["reference-antenna"])
    create_plot(args["output"], xx, yy)
end

main()

