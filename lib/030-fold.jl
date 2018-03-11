module Driver

using FileIO, JLD2
using ProgressMeter
using TTCal
using BPJSpec
using Unitful
using YAML

include("Project.jl")
include("BPJSpecVisibilities.jl")
using .BPJSpecVisibilities

struct Config
    input  :: String
    output :: String
    metadata :: String
    integrations_per_day :: Int
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["input"], dict["output"], dict["metadata"],
           dict["integrations-per-day"])
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    fold(project, config)
    Project.touch(project, config.output)
end

function fold(project, config)
    path = Project.workspace(project)
    metadata = Project.load(project, config.metadata, "metadata")

    ν  = metadata.frequencies
    Δν = fill(24u"kHz", length(ν))
    output = FBlockMatrix(MultipleFiles(joinpath(path, config.output)), ν, Δν)

    queue = collect(1:length(ν))
    pool  = CachingPool(workers())
    lck = ReentrantLock()
    prg = Progress(length(queue))
    increment() = (lock(lck); next!(prg); unlock(lck))

    @sync for worker in workers()
        @async while length(queue) > 0
            frequency = shift!(queue)
            remotecall_wait(fold, pool, project, config, output,
                            Nbase(metadata), Ntime(metadata), frequency)
            increment()
        end
    end
end

function fold(project, config, output_matrix, Nbase, Ntime, frequency)
    output  = zeros(Complex128, Nbase, config.integrations_per_day)
    weights = zeros(       Int, Nbase, config.integrations_per_day)
    input = Visibilities128(project, config.input)
    for time = 1:Ntime
        pack!(output, weights, input[time], frequency, time, config.integrations_per_day)
    end
    output ./= weights
    output[isnan.(output)] = 0
    output_matrix[frequency] = output
end

function pack!(output, weights, data, frequency, time, integrations_per_day)
    i = mod1(time, integrations_per_day)
    Nbase = size(output, 1)
    for α = 1:Nbase
        xx = data[1, frequency, α]
        yy = data[2, frequency, α]
        if xx != 0 && yy != 0
            output[α, i]  += xx
            output[α, i]  += yy
            output[α, i]  /= 2 # we take the convention I = (xx+yy)/2
            weights[α, i] += 1
        end
    end
end

end

