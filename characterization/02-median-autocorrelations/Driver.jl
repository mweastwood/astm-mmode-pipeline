module Driver

using JLD2
using ProgressMeter
using TTCal
using NLopt
using Unitful
using PyPlot

include("../../pipeline/lib/Common.jl");  using .Common

function median_autocorrelations(name)
    colors = ("r", "y", "g", "b")
    jldopen(joinpath(Common.workspace, "auto-correlations-$name.jld2"), "r") do input_file
        metadata = input_file["metadata"]
        frequencies = ustrip.(uconvert.(u"Hz", metadata.frequencies))
        jldopen(joinpath(Common.workspace, "auto-reductions-$name.jld2"), "w") do output_file
            output_file["metadata"] = metadata
            prg = Progress(256)
            for ant = 1:256
                xx = input_file[@sprintf("%03d", 2ant-1)]
                yy = input_file[@sprintf("%03d", 2ant-0)]
                xx_residual = fit(frequencies, squeeze(median(xx, 2), 2))
                yy_residual = fit(frequencies, squeeze(median(yy, 2), 2))
                output_file[@sprintf("%03d", 2ant-1)] = xx_residual
                output_file[@sprintf("%03d", 2ant-0)] = yy_residual
                next!(prg)
            end
        end
    end
    nothing
end

function fit(ν, auto)
    poly = polyfit(ν, auto, 10)
    auto_fit = polyval(ν, poly)

    #figure(1); clf()
    #plot(ν/1e6, auto, "k.")
    #plot(ν/1e6, auto_fit, "r-")
    #plot(ν/1e6, (auto.-auto_fit)./auto_fit, "k.")

    (auto.-auto_fit)./auto_fit
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

