function apply_integration_flags!(data, flags)
    Nbase, Ntime = size(data)
    prg = Progress(Nbase)
    for α = 1:Nbase
        time_series = data[α, :]
        if !all(time_series .== 0)
            flags.integration_flags[α, :] = threshold_flag(time_series)
        end
        next!(prg)
    end
    flags
end

#using PyPlot

function threshold_flag(data)
    x = 1:length(data)
    y = abs.(data)
    knots = x[2:10:end-1]
    spline = Spline1D(x, y, knots)
    deviation = abs.(y .- spline.(x))
    mad1 = median(deviation) # this is a lot faster and almost as good
    #mad2 = windowed_mad(deviation)
    flags = deviation .> 10 .* mad1

    #figure(1); clf()
    #plot(x, y, label="data")
    #plot(x, spline.(x), label="spline")
    #plot(x, spline.(x) .+ 5 .* mad1, label="unwindowed")
    #plot(x, spline.(x) .+ 5 .* mad2, label="windowed")
    #legend()

    flags
end

#function windowed_mad(deviation)
#    # the system temperature varies with time, computing the median-absolute-deviation within a
#    # window allows our threshold to also vary with time
#    N = length(deviation)
#    output = similar(deviation)
#    for idx = 1:N
#        window = max(1, idx-100):min(N, idx+100)
#        δ = view(deviation, window)
#        output[idx] = median(δ)
#    end
#    output
#end

