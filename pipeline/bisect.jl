function bisect_cyg(spw, target, output="/tmp")
    dir = getdir(spw)
    @time times, data, flags = load(joinpath(dir, target*".jld"), "times", "data", "flags")
    direction = Direction(dir"J2000", "19h59m28.35663s", "+40d44m02.0970s")
    bisect(spw, times, data, flags, direction, "cyg", output)
end

function bisect_cas(spw, target, output="/tmp")
    dir = getdir(spw)
    @time times, data, flags = load(joinpath(dir, target*".jld"), "times", "data", "flags")
    direction = Direction(dir"J2000", "23h23m24s", "58d48m54s")
    bisect(spw, times, data, flags, direction, "cas", output)
end

function bisect_vir(spw, target, output="/tmp")
    dir = getdir(spw)
    @time times, data, flags = load(joinpath(dir, target*".jld"), "times", "data", "flags")
    direction = Direction(dir"J2000", "12h30m49.42338s", "+12d23m28.0439s")
    bisect(spw, times, data, flags, direction, "vir", output)
end

function bisect_tau(spw, target, output="/tmp")
    dir = getdir(spw)
    @time times, data, flags = load(joinpath(dir, target*".jld"), "times", "data", "flags")
    direction = Direction(dir"J2000", "05h34m31.94s", "+22d00m52.2s")
    bisect(spw, times, data, flags, direction, "tau", output)
end

function bisect_sun(spw, target, output="/tmp")
    dir = getdir(spw)
    @time times, data, flags = load(joinpath(dir, target*".jld"), "times", "data", "flags")
    direction = Direction(dir"SUN")
    bisect(spw, times, data, flags, direction, "sun", output)
end

function bisect_zenith(spw, target, output="/tmp")
    dir = getdir(spw)
    @time times, data, flags = load(joinpath(dir, target*".jld"), "times", "data", "flags")
    direction = Direction(dir"AZEL", 0degrees, 90degrees)
    bisect(spw, times, data, flags, direction, "zenith", output)
end

function bisect(spw, times, data, flags, direction, name, output="/tmp")
    dir = getdir(spw)
    range = 1:length(times)
    println("Starting...")
    while true
        range1 = range[1]:floor(Int, middle(range))
        range2 = range1[end]+1:range[end]
        @show range1 range2
        @time image_with_new_phase_center(spw, times, data, flags, range1, direction,
                                          joinpath(dir, "tmp", "$name-range1"))
        @time image_with_new_phase_center(spw, times, data, flags, range2, direction,
                                          joinpath(dir, "tmp", "$name-range2"))

        if output != ""
            run(`scp $(joinpath(dir, "tmp", "$name-range1.fits")) mweastwood@smaug.caltech.edu:$output`)
            run(`scp $(joinpath(dir, "tmp", "$name-range2.fits")) mweastwood@smaug.caltech.edu:$output`)
        end

        while true
            print("1 or 2? ")
            input = chomp(readline())
            if input == "1"
                range = range1
                break
            elseif input == "2"
                range = range2
                break
            elseif contains(input, ":")
                parts = split(input, ":", limit=2)
                range = parse(Int, parts[1]):parse(Int, parts[2])
                break
            elseif input == "q"
                @goto quit
            else
                println("Oops")
            end
        end
    end
    @label quit
end

