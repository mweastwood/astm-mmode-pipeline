module Driver

using CasaCore.Tables
using JLD2
using ProgressMeter
using TTCal
using YAML

include("Project.jl")
include("DADA2MS.jl")

struct Config
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
    Config(subbands)
end

function go(project_file, dada2ms_file, config_file)
    project = Project.load(project_file)
    dada2ms = DADA2MS.load(dada2ms_file)
    config  = load(config_file)
    getdata(project, dada2ms, config)
    Project.touch(project, "raw-data")
end

function getdata(project, dada2ms, config)
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

    jldopen(joinpath(Project.workspace(project), "raw-visibilities.jld2"), "w") do file
        metadata_list = Vector{TTCal.Metadata}(Ntime)
        @sync for worker in workers()
            @async while length(queue) > 0
                index = shift!(queue)
                data, metadata = remotecall_fetch(_getdata, pool, dada2ms, config, index)
                file[o6d(index)] = data
                metadata_list[index] = metadata
                increment()
            end
        end
        master_metadata = metadata_list[1]
        for metadata in metadata_list[2:end]
            TTCal.merge!(master_metadata, metadata, axis=:time)
        end
        file["metadata"] = master_metadata
    end
    nothing
end

o6d(i) = @sprintf("%06d", i)

function _getdata(dada2ms, config, index)
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

