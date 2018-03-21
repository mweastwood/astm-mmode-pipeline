module Driver

using CasaCore.Tables
using CasaCore.Measures
using JLD2
using ProgressMeter
using TTCal
using BPJSpec
using YAML

include("Project.jl")
include("DADA2MS.jl")

struct Config
    output :: String
    output_metadata :: String
    subbands :: Dict{Int, Vector{Int}}
    times :: Vector{Int}
    keep :: Vector{Bool}
end

function load(file, dada2ms)
    dict = YAML.load(open(file))
    subbands = Dict{Int, Vector{Int}}()
    for (key, value) in dict["subbands"]
        subband = key
        if value == "all"
            subbands[subband] = collect(1:109)
        elseif value isa Int
            subbands[subband] = [value]
        else
            subbands[subband] = value
        end
        DADA2MS.load!(dada2ms, subband)
    end
    times = get(dict, "times", collect(1:DADA2MS.number(dada2ms)))
    Config(dict["output"], dict["output_metadata"], subbands, times,
           get(dict, "pol", [true, false, false, true]))
end

function go(project_file, dada2ms_file, config_file)
    project = Project.load(project_file)
    dada2ms = DADA2MS.load(dada2ms_file)
    config  = load(config_file, dada2ms)
    getdata(project, dada2ms, config)
    Project.touch(project, config.output)
end

function getdata(project, dada2ms, config)
    # load the list of files for each subband

    queue = collect(1:length(config.times))
    pool  = CachingPool(workers())
    lck = ReentrantLock()
    prg = Progress(length(queue))
    increment() = (lock(lck); next!(prg); unlock(lck))

    path = Project.workspace(project)
    Project.set_stripe_count(project, config.output, 1)
    output = create(BPJSpec.SimpleBlockArray{Complex64, 3},
                    MultipleFiles(joinpath(path, config.output)), length(queue))
    metadata = Vector{TTCal.Metadata}(length(queue))

    @sync for worker in workers()
        @async while length(queue) > 0
            index = shift!(queue)
            time  = config.times[index]
            _metadata = remotecall_fetch(getdata!, pool, output, dada2ms, config, index, time)
            metadata[index] = _metadata
            increment()
        end
    end

    master_metadata = metadata[1]
    for _metadata in metadata[2:end]
        TTCal.merge!(master_metadata, _metadata, axis=:time)
    end
    Project.save(project, config.output_metadata, "metadata", master_metadata)

    nothing
end

function getdata!(output, dada2ms, config, index, time)
    data, metadata = internal_getdata(dada2ms, config, time)
    output[index] = data
    metadata
end

function internal_getdata(dada2ms, config, index)
    subbands = sort(collect(keys(config.subbands)))
    data, metadata = run_dada2ms(dada2ms, config, first(subbands), index)
    for subband in subbands[2:end]
        _data, _metadata = run_dada2ms(dada2ms, config, subband, index)
        data = cat(2, data, _data)
        TTCal.merge!(metadata, _metadata, axis=:frequency)
    end
    data, metadata
end

function run_dada2ms(dada2ms, config, subband, index)
    channels = config.subbands[subband]
    ms = DADA2MS.run(dada2ms, subband, index)
    raw_data = ms["DATA"] :: Array{Complex64, 3}
    metadata = TTCal.Metadata(ms)
    TTCal.slice!(metadata, channels, axis=:frequency)
    data = raw_data[config.keep, channels, :]
    Tables.delete(ms)
    data, metadata
end

end

