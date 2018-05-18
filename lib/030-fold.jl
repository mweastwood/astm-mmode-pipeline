module Driver

using ProgressMeter
using TTCal
using BPJSpec
using Unitful
using YAML

include("Project.jl")

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

# NOTE
# ====
# We'd like to do the folding with a single pass through the dataset. This means we'd really like to
# read the data once, and write it to disk at the correct location before moving on. Generally mmap
# would be a useful tool here, but lustre has problems with mmap. It would also be nice if JLD2 let
# us read/write to arbitrary parts of a matrix, but it does not. Therefore we will use a binary
# format here and simply seek to the correct location whenever necessary.

function fold(project, config)
    path = Project.workspace(project)
    metadata = Project.load(project, config.metadata, "metadata")
    isdir(joinpath(path, config.output)) || mkpath(joinpath(path, config.output))

    ν  = metadata.frequencies
    Δν = fill(24u"kHz", length(ν))
    output = create(FBlockMatrix, MultipleFiles(joinpath(path, config.output)), ν, Δν)

    # Open all of the files
    input = BPJSpec.load(joinpath(path, config.input))
    numerator_files   = [open(joinpath(path, config.output, @sprintf("%04d.numerator",   β)), "w+")
                            for β = 1:Nfreq(metadata)]
    denominator_files = [open(joinpath(path, config.output, @sprintf("%04d.denominator", β)), "w+")
                            for β = 1:Nfreq(metadata)]

    prg = Progress(Nfreq(metadata))
    for β = 1:Nfreq(metadata)
        write(  numerator_files[β], zeros(Complex128, Nbase(metadata), config.integrations_per_day))
        write(denominator_files[β], zeros(       Int, Nbase(metadata), config.integrations_per_day))
        next!(prg)
    end

    prg = Progress(Ntime(metadata))
    for idx = 1:Ntime(metadata)
        _fold(numerator_files, denominator_files, input, config.integrations_per_day, idx)
        next!(prg)
    end
    normalize!(output, project, config, metadata)

    foreach(close,   numerator_files)
    foreach(close, denominator_files)
    for β = 1:Nfreq(metadata)
        rm(joinpath(path, @sprintf("%04d.numerator",   β)), force=true)
        rm(joinpath(path, @sprintf("%04d.denominator", β)), force=true)
    end
end

function _fold(numerator_files, denominator_files, input, integrations_per_day, idx)
    data = input[idx]
    for β = 1:length(numerator_files)
        xx = view(data, 1, β, :)
        yy = view(data, 2, β, :)
        pack!(numerator_files[β], denominator_files[β], xx, yy, integrations_per_day, idx)
    end
    nothing
end

function pack!(numerator_file, denominator_file, xx, yy, integrations_per_day, idx)
    Nbase = length(xx)
    idx = mod1(idx, integrations_per_day)
    offset1 = Nbase*(idx-1)*sizeof(Complex128)
    offset2 = Nbase*(idx-1)*sizeof(Int)

    I = 0.5 .* (xx .+ yy)
    w = Int.((xx .!= 0) .& (yy .!= 0))

    seek(  numerator_file, offset1)
    seek(denominator_file, offset2)
    I′ = read(  numerator_file, Complex128, Nbase)
    w′ = read(denominator_file,        Int, Nbase)

    seek(  numerator_file, offset1)
    seek(denominator_file, offset2)
    write(  numerator_file, I.+I′)
    write(denominator_file, w.+w′)

    nothing
end

function normalize!(output, project, config, metadata)
    size = (Nbase(metadata), config.integrations_per_day)
    path = joinpath(Project.workspace(project), config.output)

    queue = collect(1:Nfreq(metadata))
    pool  = CachingPool(workers())
    lck = ReentrantLock()
    prg = Progress(length(queue))
    increment() = (lock(lck); next!(prg); unlock(lck))

    @sync for worker in workers()
        @async while length(queue) > 0
            frequency = shift!(queue)
            remotecall_wait(_normalize!, pool, output, path, size, frequency)
            increment()
        end
    end
end

function _normalize!(output, path, size, frequency)
    open(joinpath(path, @sprintf("%04d.denominator", frequency)), "r") do denominator_file
        open(joinpath(path, @sprintf("%04d.numerator", frequency)), "r") do numerator_file
            numerator   = read(  numerator_file, Complex128, size)
            denominator = read(denominator_file,        Int, size)
            no_data = denominator .== 0
            numerator[no_data]   = 0
            denominator[no_data] = 1
            numerator ./= denominator
            output[frequency] = numerator
        end
    end
end

end

