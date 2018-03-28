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
            remotecall_wait(_getmmodes, pool, input, output, hierarchy, frequency, config.option)
            increment()
        end
    end

    # fix the phase of the m-modes in cases where we have moved the time origin
    if config.option == "even-odd"
        dϕ = -π/Ntime
        @. mmodes *= cis(dϕ)
    elseif config.option == "even"
        dϕ = -2π/Ntime
        @. mmodes *= cis(dϕ)
    end
end

function _getmmodes(input, output, hierarchy, frequency, option)
    array = input[frequency]
    Ntime = size(array, 2)
    if option == "even-odd"
        # difference odd and even integrations
        array = array[:, 2:2:end] - array[:, 1:2:end]
        dϕ = -π/Ntime
    elseif option == "odd"
        # select only odd integrations
        array = array[:, 1:2:end]
        dϕ = 0.0
    elseif option == "even"
        # select only even integrations
        array = array[:, 2:2:end]
        dϕ = -2π/Ntime
    else
        dϕ = 0.0
    end
    # put time on the fast axis
    transposed_array = permutedims(array, (2, 1))
    # compute the m-modes
    compute!(MModes, output, hierarchy, transposed_array, frequency)
end

end

