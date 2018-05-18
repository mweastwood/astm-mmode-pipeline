#!/usr/bin/env julia-0.6

# test spawning workers on all of the ASTM machines

function main()
    for astm = 4:13
        time = time_worker_spawn(astm)
        println(" ", rpad(name(astm)*" ", 7, "─"), lpad(@sprintf(" %.1f s", time), 8, "─"))
    end
end

function time_worker_spawn(astm)
    @elapsed addprocs([(name(astm), 1)])
end

name(astm) = @sprintf("astm%02d", astm)

main()

