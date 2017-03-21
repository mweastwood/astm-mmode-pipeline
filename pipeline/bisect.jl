function bisect_cyg(spw, target)
    dir = getdir(spw)
    @time times, data, flags = load(joinpath(dir, target*".jld"), "times", "data", "flags")
    direction = Direction(dir"J2000", "19h59m28.35663s", "+40d44m02.0970s")
    bisect(spw, times, data, flags, direction)
end

function bisect_cas(spw, target)
    dir = getdir(spw)
    @time times, data, flags = load(joinpath(dir, target*".jld"), "times", "data", "flags")
    direction = Direction(dir"J2000", "23h23m24s", "58d48m54s")
    bisect(spw, times, data, flags, direction)
end

function bisect(spw, times, data, flags, direction)
    dir = getdir(spw)
    range = 1:length(times)
    println("Starting...")
    while true
        range1 = range[1]:floor(Int, middle(range))
        range2 = range1[end]+1:range[end]
        @show range1 range2
        @time image_with_new_phase_center(spw, times, data, flags, range1, direction,
                                          joinpath(dir, "tmp", "cyg-range1"))
        @time image_with_new_phase_center(spw, times, data, flags, range2, direction,
                                          joinpath(dir, "tmp", "cyg-range2"))

        run(`scp $(joinpath(dir, "tmp", "cyg-range1.fits")) mweastwood@smaug.caltech.edu:/tmp`)
        run(`scp $(joinpath(dir, "tmp", "cyg-range2.fits")) mweastwood@smaug.caltech.edu:/tmp`)

        while true
            print("1 or 2? ")
            input = chomp(readline())
            if input == "1"
                range = range1
                break
            elseif input == "2"
                range = range2
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

