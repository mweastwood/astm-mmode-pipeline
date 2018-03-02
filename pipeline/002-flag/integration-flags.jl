function apply_integration_flags!(data, flags, threshold; windowed=false)
    Nbase, Ntime = size(data)
    prg = Progress(Nbase)
    for α = 1:Nbase
    #for α = 30741 # longest baseline
    #for α = 19520 # problematic baseline at integration 763
    #for α = 314 # erroneously flagged at integration 2000 (when using unwindowed median)
    #for α = 4228
        time_series = data[α, :]
        if !all(time_series .== 0)
            flags.integration_flags[α, :] = threshold_flag(time_series, threshold, windowed)
        end
        next!(prg)
    end
    flags
end

#using PyPlot

function threshold_flag(data, threshold, windowed)
    x = 1:length(data)
    y = abs.(data)
    f = y .== 0
    knots = x[.!f][2:10:end-1]
    spline = Spline1D(x[.!f], y[.!f], knots)
    z = spline.(x)
    deviation = abs.(y .- z)
    if windowed
        mad = windowed_mad(deviation)
    else
        mad = median(deviation)
    end
    flags = deviation .> threshold .* mad

    # iterate on the spline once
    f .|= flags
    knots = x[.!f][2:10:end-1]
    spline = Spline1D(x[.!f], y[.!f], knots)
    z = spline.(x)
    deviation = abs.(y .- z)
    flags = deviation .> threshold .* mad

    #figure(1); clf()
    #plot(x, y, "k-")
    #plot(x, z, "b-")
    #plot(x, z+threshold*mad, "r-")

    flags
end

function windowed_mad(deviation)
    # the system temperature varies with time, computing the median-absolute-deviation within a
    # window allows our threshold to also vary with time
    N = length(deviation)
    output = similar(deviation)
    for idx = 1:N
        window = max(1, idx-100):min(N, idx+100)
        output[idx] = do_the_thing(deviation, window)
    end
    output
end

function do_the_thing(deviation, window)
    δ = view(deviation, window)
    median(δ)
end

