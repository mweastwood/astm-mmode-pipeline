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
    option :: String
end

function load(file)
    dict = YAML.load(open(file))
    option = get(dict, "option", "all")
    Config(dict["input"], dict["output"],
           dict["metadata"], dict["hierarchy"],
           dict["delete_input"], option)
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    getmmodes(project, config)
    if config.delete_input
        rm(joinpath(Project.workspace(project), config.input), recursive=true)
    end
end

function getmmodes(project, config)
    path = Project.workspace(project)

    ttcal_metadata = Project.load(project, config.metadata, "metadata")
    metadata  = BPJSpec.from_ttcal(ttcal_metadata)
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
            remotecall_wait(_getmmodes, pool, input, output, hierarchy, frequency, config.option)
            increment()
        end
    end

    # fix the phase of the m-modes in cases where we have moved the time origin
    if config.option == "even"
        println("fixing the phase")
        dϕ = -2π/Ntime(ttcal_metadata)
        fix(block) = block*cis(dϕ)
        @. output = fix(output)
    end
end

function _getmmodes(input, output, hierarchy, frequency, option)
    array = input[frequency]
    Ntime = size(array, 2)
    odd  = @view array[:, 1:2:end]
    even = @view array[:, 2:2:end]
    if option == "odd"
        array = odd
    elseif option == "even"
        array = even
    end
    # put time on the fast axis
    transposed_array = permutedims(array, (2, 1))
    # compute the m-modes
    compute!(MModes, output, hierarchy, transposed_array, frequency)
end

end

