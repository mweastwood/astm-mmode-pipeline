#using PyPlot

function powerlaw()
    maps = HealpixMap[]
    frequencies = Float64[]
    for spw = 4:2:18
        dir = getdir(spw)
        meta = getmeta(spw, "rainy")
        map = readhealpix(joinpath(dir, "map-wiener-filtered-rainy-itrf.fits"))
        push!(maps, map)
        push!(frequencies, meta.channels[55])
    end
    powerlaw(maps, frequencies)
end

function powerlaw(maps, frequencies)
    N = length(frequencies)
    x = frequencies/70e6
    A = [log10(x) ones(N)]
    index = zeros(length(maps[1]))
    amplitude = zeros(length(maps[1]))
    for pixel = 1:length(index)
        y = [map[pixel] for map in maps]
        if all(y .> 0)
            line = A\log10(y)
            index[pixel] = line[1]
            amplitude[pixel] = 10^line[2]
        end
    end
    amplitude[abs(amplitude) .> 1e20] = 0
    writehealpix("spectral-index.fits", HealpixMap(index), replace=true)
    writehealpix("amplitude.fits", HealpixMap(amplitude), replace=true)
end

