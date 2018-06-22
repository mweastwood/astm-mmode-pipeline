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
    interpolating_visibilities :: String
    replacement_threshold :: Float64
    integrations_per_day  :: Int
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
           get(dict, "interpolating-visibilities", ""),
           get(dict, "replacement-threshold", 0.0),
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

    Project.set_stripe_count(project, config.output, 1)
    input  = BPJSpec.load(joinpath(path, config.input))
    output = create(MModes, MultipleFiles(joinpath(path, config.output)),
                    metadata, hierarchy)

    queue = collect(1:length(input.frequencies))
    lck = ReentrantLock()
    prg = Progress(length(queue))
    increment() = (lock(lck); next!(prg); unlock(lck))

    @sync for worker in workers()
        @async while length(queue) > 0
            frequency = shift!(queue)
            remotecall_wait(_getmmodes, worker, input, output,
                            hierarchy, project, config, frequency)
            increment()
        end
    end
end

function _getmmodes(input, output, hierarchy, project, config, frequency)
    V = input[frequency]
    flag!(V, project, config, frequency)
    W = fold(V, config)
    if config.interpolating_visibilities != ""
        interpolate!(W, project, config, frequency)
    end
    _getmmodes!(output, W, hierarchy, config, frequency)
end

function flag!(V, project, config, frequency)
    flags = Project.load(project, config.input_flags, "flags")
    V[flags.bits[:, frequency, :]] = 0 # apply the flags
end

function fold(V, config)
    Nbase, Ntime = size(V)
    numerator   = zeros(eltype(V), Nbase, config.integrations_per_day)
    denominator = zeros(      Int, Nbase, config.integrations_per_day)
    for idx = 1:Ntime, α = 1:Nbase
        if V[α, idx] != 0
            numerator[  α, mod1(idx, config.integrations_per_day)] += V[α, idx]
            denominator[α, mod1(idx, config.integrations_per_day)] += 1
        end
    end
    no_data = denominator .== 0
    numerator[no_data]   = 0
    denominator[no_data] = 1
    output = numerator ./ denominator
    output
end

function interpolate!(V, project, config, frequency)
    path = Project.workspace(project)
    interpolating_visibilities = BPJSpec.load(joinpath(path, config.interpolating_visibilities))
    W = interpolating_visibilities[frequency]
    @assert size(W) == size(V)

    flags = V .== 0
    diff  = V .- W
    σ = sqrt(mean(abs2.(diff[.!flags])))

    # Fill in any gaps in the data
    Nbase, Ntime = size(V)
    for α = 1:Nbase
        all(flags[α, :]) && continue
        for time = 1:Ntime
            if flags[α, time]
                # Replace a gap in the data with the interpolated value
                V[α, time] = W[α, time]
            end
            if abs(diff[α, time]) > config.replacement_threshold * σ
                # Replace a visibility that seems to be an outlier
                V[α, time] = W[α, time]
            end
        end
    end
end

function _getmmodes!(output, V, hierarchy, config, frequency)
    Ntime = size(V, 2)
    odd  = @view V[:, 1:2:end]
    even = @view V[:, 2:2:end]
    if config.option == "odd"
        W  = odd
        dϕ = 0.0
    elseif config.option == "even"
        W  = even
        dϕ = -2π/Ntime
    else
        W  = V
        dϕ = 0.0
    end
    # put time on the fast axis
    transposed_array = permutedims(W, (2, 1))
    # compute the m-modes
    compute!(MModes, output, hierarchy, transposed_array, frequency; dϕ=dϕ)
end

end

