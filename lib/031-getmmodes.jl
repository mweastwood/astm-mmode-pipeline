module Driver

using ProgressMeter
using TTCal
using BPJSpec
using YAML

include("Project.jl")

struct Config
    input  :: String
    output :: String
    mmax   :: Int
    delete_input :: Bool
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["input"], dict["output"], dict["mmax"], dict["delete_input"])
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
    input  = FBlockMatrix(joinpath(path, config.input))
    output = MModes(MultipleFiles(joinpath(path, config.output)), config.mmax,
                    BPJSpec.frequencies(input), BPJSpec.bandwidth(input))

    queue = collect(1:length(BPJSpec.frequencies(input)))
    pool  = CachingPool(workers())
    lck = ReentrantLock()
    prg = Progress(length(queue))
    increment() = (lock(lck); next!(prg); unlock(lck))

    @sync for worker in workers()
        @async while length(queue) > 0
            frequency = shift!(queue)
            remotecall_wait(_getmmodes, pool, input, output, frequency)
            increment()
        end
    end
end

function _getmmodes(input, output, frequency)
    # put time on the fast axis
    transposed_array = permutedims(input[frequency], (2, 1))
    # compute the m-modes
    compute!(output, transposed_array, frequency)
end

end

