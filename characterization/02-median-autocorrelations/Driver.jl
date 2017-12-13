module Driver

using JLD2
using ProgressMeter
using TTCal
using NLopt
using Unitful
using PyPlot
using Dierckx

include("../../pipeline/lib/Common.jl");  using .Common

function median_autocorrelations(name)
    colors = ("r", "y", "g", "b")
    jldopen(joinpath(Common.workspace, "auto-correlations-$name.jld2"), "r") do input_file
        metadata = input_file["metadata"]
        frequencies = ustrip.(uconvert.(u"Hz", metadata.frequencies))
        jldopen(joinpath(Common.workspace, "auto-reductions-$name.jld2"), "w") do output_file
            output_file["metadata"] = metadata
            prg = Progress(256)
            flags = Common.flag_antennas(18, "rainy")
            for ant = 32
                if ant in flags
                    xx_residual = fill(NaN, length(metadata.frequencies))
                    yy_residual = fill(NaN, length(metadata.frequencies))
                else
                    xx = input_file[@sprintf("%03d", 2ant-1)]
                    yy = input_file[@sprintf("%03d", 2ant-0)]
                    xx_residual = fit(frequencies, squeeze(median(xx, 2), 2))
                    #yy_residual = fit(frequencies, squeeze(median(yy, 2), 2))
                    error("stop")
                end
                output_file[@sprintf("%03d", 2ant-1)] = xx_residual
                output_file[@sprintf("%03d", 2ant-0)] = yy_residual
                next!(prg)
            end
        end
    end
    nothing
end

function fit(ν, auto)
    original = copy(auto)
    flags = original .< 0
    for idx = 1:3
        auto = copy(original)
        knots  = ν[.!flags][2:10:end-1]
        spline = Spline1D(ν[.!flags], auto[.!flags], knots)
        flags = flag((auto .- spline(ν))./spline(ν))
        #print("Continue? ")
        #inp = readline() |> chomp
        #inp == "q" && break
    end

    poly = polyfit(ν[.!flags], auto[.!flags], 10)
    poly_fit = polyval(ν, poly)
    residual = auto./poly_fit

    figure(1); clf()
    plot(ν/1e6, auto, "r-")
    auto[flags] = NaN
    plot(ν/1e6, auto, "k-")
    plot(ν/1e6, poly_fit, "b-")

    figure(2); clf()
    plot(ν/1e6, residual, "r-")
    residual[flags] = NaN
    plot(ν/1e6, residual, "k-")

    residual[flags] = NaN
    residual .- 1
end

function flag(δ)
    mad = median(abs.(δ))
    flags = δ .> 10*mad
    flags
end

function polyfit(x, y, order)
    z = x./74e6
    N = length(x)
    A = ones(N, 1)
    for o = 1:order
        A = [z.^o A]
    end
    A\y
end

function polyval(x, coeff)
    z = x./74e6
    output = zeros(size(x))
    for p in coeff
        output .= z.*output .+ p
    end
    output
end

end

