module Driver

using CasaCore.Tables
using CasaCore.Measures
using JLD2
using ProgressMeter
using TTCal
using YAML

include("Project.jl")
include("Matrices.jl")
include("DADA2MS.jl")

struct Config
    output :: String
    output_metadata :: String
    subbands :: Dict{Int, Vector{Int}}
end

function load(file)
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
    end
    Config(dict["output"], dict["output_metadata"], subbands)
end

function go(project_file, dada2ms_file, config_file)
    project = Project.load(project_file)
    dada2ms = DADA2MS.load(dada2ms_file)
    config  = load(config_file)
    getdata(project, dada2ms, config)
    Project.touch(project, config.output)
end

function getdata(project, dada2ms, config)
    path = Project.workspace(project)

    # load the list of files for each subband
    for subband in keys(config.subbands)
        DADA2MS.load!(dada2ms, subband)
    end

    Ntime = DADA2MS.number(dada2ms)
    queue = collect(1:Ntime)
    pool  = CachingPool(workers())
    lck = ReentrantLock()
    prg = Progress(length(queue))
    increment() = (lock(lck); next!(prg); unlock(lck))

    Project.set_stripe_count(project, config.output, 1)
    output = Matrices.Visibilities(joinpath(path, config.output), Ntime)
    metadata = Vector{TTCal.Metadata}(Ntime)

    @sync for worker in workers()
        @async while length(queue) > 0
            index = shift!(queue)
            _metadata = remotecall_fetch(getdata!, pool, output, dada2ms, config, index)
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

function getdata!(output, dada2ms, config, index)
    data, metadata = internal_getdata(dada2ms, config, index)
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
    keep = [true; false; false; true]
    channels = config.subbands[subband]
    ms = DADA2MS.run(dada2ms, subband, index)
    raw_data = ms["DATA"] :: Array{Complex64, 3}
    metadata = TTCal.Metadata(ms)
    TTCal.slice!(metadata, channels, axis=:frequency)
    data = raw_data[keep, channels, :]
    Tables.delete(ms)
    data, metadata
end

end

