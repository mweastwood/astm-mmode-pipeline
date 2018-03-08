#!/usr/bin/env julia-0.6

info(now())
using ArgParse

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table s begin
        "--local-workers"
            help = "the number of local workers to launch"
            arg_type = Int
        "--remote-workers"
            help = "the number of remote workers to launch"
            arg_type = Int
        "driver"
            help = "path to a Julia file that defines `Driver.go(...)`"
            arg_type = String
            required = true
        "args"
            help = "any remaining arguments will be passed to `Driver.go(...)`"
            nargs = '*'
    end
    return parse_args(s)
end

args = parse_commandline()
path = abspath(normpath(args["driver"]))
include(path)

function main(args)
    if args["local-workers"] !== nothing
        info("Launching local workers")
        addprocs(args["local-workers"], exeflags=`-L $path`)
    end

    if args["remote-workers"] !== nothing
        info("Launching remote workers")
        N = args["remote-workers"]
        machines = ["astm04", "astm05", "astm06", "astm07", "astm08",
                    "astm09", "astm10", "astm11", "astm12", "astm13"]
        addprocs([(machine, N) for machine in machines], exeflags=`-L $path`)
    end

    if args["local-workers"] !== nothing || args["remote-workers"] !== nothing
        @sync for worker in workers()
            @async remotecall_wait(include, worker, path)
        end
    end

    info("Starting computation")
    Driver.go(args["args"]...)
end
main(args)

