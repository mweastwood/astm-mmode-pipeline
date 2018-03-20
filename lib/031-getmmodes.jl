module Driver

using ProgressMeter
using TTCal
using BPJSpec
using YAML

include("Project.jl")

struct Config
    input  :: String
    output :: String
    metadata :: String
    hierarchy :: String
    delete_input :: Bool
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["input"], dict["output"],
           dict["metadata"], dict["hierarchy"], dict["delete_input"])
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    getmmodes(project, config)
    if config.delete_input
        rm(joinpath(Project.workspace(project), config.input), recursive=true)
    end
    Project.touch(project, config.output)
end

function getmmodes(project, config)
    path = Project.workspace(project)

    metadata  = BPJSpec.from_ttcal(Project.load(project, config.metadata, "metadata"))
    hierarchy = Project.load(project, config.hierarchy, "hierarchy")

    input  = BPJSpec.load(joinpath(path, config.input))
    output = create(MModes, MultipleFiles(joinpath(path, config.output)),
                    metadata, hierarchy)

    queue = collect(1:length(input.frequencies))
    pool  = CachingPool(workers())
    lck = ReentrantLock()
    prg = Progress(length(queue))
    increment() = (lock(lck); next!(prg); unlock(lck))

    @sync for worker in workers()
        @async while length(queue) > 0
            frequency = shift!(queue)
            remotecall_wait(_getmmodes, pool, input, output, hierarchy, frequency)
            increment()
        end
    end
end

function _getmmodes(input, output, hierarchy, frequency)
    # put time on the fast axis
    transposed_array = permutedims(input[frequency], (2, 1))
    # compute the m-modes
    compute!(MModes, output, hierarchy, transposed_array, frequency)
end

end

