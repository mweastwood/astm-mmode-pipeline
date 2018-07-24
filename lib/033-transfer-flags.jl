# Take flags from one set of m-modes and apply them to a different set of m-modes.
module Driver

using BPJSpec
using ProgressMeter
using YAML

include("Project.jl")

struct Config
    input_to_flag :: String
    input_already_flagged :: String
    output :: String
    same_across_all_frequencies :: Bool
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["input-to-flag"],
           dict["input-already-flagged"],
           dict["output"],
           get(dict, "same-across-all-frequencies", false))
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    transfer_flags(project, config)
end

function transfer_flags(project, config)
    path = Project.workspace(project)
    to_flag         = BPJSpec.load(joinpath(path, config.input_to_flag))
    already_flagged = BPJSpec.load(joinpath(path, config.input_already_flagged))
    output = similar(to_flag, MultipleFiles(joinpath(path, config.output)))
    if config.same_across_all_frequencies
        spread_the_flags(output, to_flag, already_flagged)
    else
        output′ = ProgressBar(output)
        @. output′ = _transfer_flags(to_flag, already_flagged)
    end
end

function _transfer_flags(to_flag, already_flagged)
    output = copy(to_flag)
    output[already_flagged .== 0] = 0
    output
end

function spread_the_flags(output, to_flag, already_flagged)
    Nfreq = length(output.frequencies)
    queue = collect(0:output.mmax)
    lck = ReentrantLock()
    prg = Progress(length(queue))
    increment() = (lock(lck); next!(prg); unlock(lck))
    @sync for worker in workers()
        @async while length(queue) > 0
            m = shift!(queue)
            remotecall_wait(_spread_the_flags, worker, output, to_flag, already_flagged, m, Nfreq)
            increment()
        end
    end
end

function _spread_the_flags(output, to_flag, already_flagged, m, Nfreq)
    flags = fill(false, length(to_flag[m, 1]))
    for β = 1:Nfreq
        block = already_flagged[m, β]
        flags .|= block .== 0
    end
    for β = 1:Nfreq
        block = to_flag[m, β]
        block[flags] .= 0
        output[m, β] = block
    end
end

end

