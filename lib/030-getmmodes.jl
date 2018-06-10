module Driver

using FileIO, JLD2
using ProgressMeter
using TTCal
using BPJSpec
using YAML

include("Project.jl")
include("FlagDefinitions.jl"); using .FlagDefinitions

struct Config
    input        :: String
    input_flags  :: String
    output       :: String
    metadata     :: String
    hierarchy    :: String
    integrations_per_day :: Int
    delete_input :: Bool
    option       :: String
end

function load(file)
    dict = YAML.load(open(file))
    option = get(dict, "option", "all")
    Config(dict["input"],
           dict["input-flags"],
           dict["output"],
           dict["metadata"],
           dict["hierarchy"],
           dict["integrations-per-day"],
           dict["delete-input"],
           option)
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
    path_to_flags = joinpath(path, config.input_flags*".jld2")

    input  = BPJSpec.load(joinpath(path, config.input))
    output = create(MModes, MultipleFiles(joinpath(path, config.output)),
                    metadata, hierarchy)

    queue = collect(1:length(input.frequencies))
    pool  = CachingPool(workers())
    lck = ReentrantLock()
    prg = Progress(length(queue))
    increment() = (lock(lck); next!(prg); unlock(lck))

    function closure(input, output, frequency)
        _getmmodes(input, output, hierarchy, path_to_flags, frequency,
                   config.integrations_per_day, config.option)
    end

    @sync for worker in workers()
        @async while length(queue) > 0
            frequency = shift!(queue)
            remotecall_wait(closure, pool, input, output, frequency)
            increment()
        end
    end
end

function _getmmodes(input, output, hierarchy, path_to_flags, frequency,
                    integrations_per_day, option)
    try
        array = input[frequency]
        flags = FileIO.load(path_to_flags, "flags")
        __getmmodes(array, output, hierarchy, flags, frequency,
                    integrations_per_day, option)
    catch err
        println(err)
        rethrow(err)
    end
end

function __getmmodes(array, output, hierarchy, flags, frequency,
                     integrations_per_day, option)
    array[flags.bits[:, frequency, :]] = 0 # apply the flags
    folded_array = _fold(array, integrations_per_day)
    Ntime = size(folded_array, 2)
    odd  = @view folded_array[:, 1:2:end]
    even = @view folded_array[:, 2:2:end]
    if option == "odd"
        folded_array = odd
        dϕ = 0.0
    elseif option == "even"
        folded_array = even
        dϕ = -2π/Ntime
    else
        dϕ = 0.0
    end
    # put time on the fast axis
    transposed_array = permutedims(folded_array, (2, 1))
    # compute the m-modes
    compute!(MModes, output, hierarchy, transposed_array, frequency; dϕ=dϕ)
end

function _fold(array, integrations_per_day)
    Nbase, Ntime = size(array)
    numerator   = zeros(eltype(array), Nbase, integrations_per_day)
    denominator = zeros(          Int, Nbase, integrations_per_day)
    for idx = 1:Ntime, α = 1:Nbase
        if array[α, idx] != 0
            numerator[α, mod1(idx, integrations_per_day)] += array[α, idx]
            denominator[α, mod1(idx, integrations_per_day)] += 1
        end
    end
    no_data = denominator .== 0
    numerator[no_data]   = 0
    denominator[no_data] = 1
    numerator ./ denominator
end

end

