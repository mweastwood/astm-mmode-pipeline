module Driver

using ProgressMeter
using TTCal
using BPJSpec
using Unitful, UnitfulAstro
using YAML

include("Project.jl")
include("TTCalDatasets.jl")
using .TTCalDatasets

struct Config
    input    :: String
    output   :: String
    output_amplitude :: String
    coherencies      :: String
    metadata :: String
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["input"],
           dict["output"],
           dict["output-amplitude"],
           dict["coherencies"],
           dict["metadata"])
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    subrfi(project, config)
end

function subrfi(project, config)
    path = Project.workspace(project)
    metadata    = Project.load(project, config.metadata,    "metadata")
    coherencies = Project.load(project, config.coherencies, "coherencies")
    input  = BPJSpec.load(joinpath(path, config.input))
    output = similar(input, MultipleFiles(joinpath(path, config.output)))
    amplitude = zeros(2, Nfreq(metadata), Ntime(metadata), length(coherencies))

    queue = collect(1:Ntime(metadata))
    lck = ReentrantLock()
    prg = Progress(length(queue))
    increment() = (lock(lck); next!(prg); unlock(lck))

    @sync for worker in workers()
        @async while length(queue) > 0
            integration = shift!(queue)
            amp = remotecall_fetch(_subrfi, worker, input, output,
                                   metadata, coherencies, integration)
            amplitude[:, :, integration, :] = amp
            increment()
        end
    end

    Project.save(project, config.output_amplitude, "amplitude", amplitude)
end

function _subrfi(input, output, metadata, coherencies, integration)
    data  = input[integration]
    model = [ttcal_to_array(coherency) for coherency in coherencies]
    short_baselines = identify_short_baselines(metadata, 15.0)
    subtracted_data, amplitude = _subrfi(data, model, short_baselines)
    output[integration] = subtracted_data
    amplitude
end

function _subrfi(data, coherencies, short_baselines)
    original_flags = data .== 0
    Npol, Nfreq, Nbase = size(data)
    amplitude  = zeros(Npol, Nfreq, length(coherencies))
    subtracted = zeros(Complex128, Npol, Nfreq, Nbase)
    for freq = 1:Nfreq, pol = 1:Npol
        x = data[pol, freq, :]
        for (index, coherency) in enumerate(coherencies)
            y = coherency[pol, freq, :]
            flags = original_flags[pol, freq, :]
            flags .|= short_baselines
            amplitude[pol, freq, index] = sub!(x, y, flags)
        end
        subtracted[pol, freq, :] = x
    end
    subtracted[original_flags] = 0
    subtracted, amplitude
end

function sub!(x, y, flags)
    xf = x[.!flags]
    yf = y[.!flags]
    xx = [xf; conj(xf)]
    yy = [yf; conj(yf)]
    numerator   = dot(xx, yy)
    denominator = dot(yy, yy)
    if denominator != 0
        scale  = real(numerator/denominator)
        to_sub = scale.*y
        #to_sub[flags] = 0
        x .-= to_sub
    else
        scale = 0.0
    end
    scale
end

function identify_short_baselines(metadata, minuvw=15.0)
    flags = fill(false, Nbase(metadata))
    ν = minimum(metadata.frequencies)
    λ = u"c" / ν
    α = 1
    for antenna1 = 1:Nant(metadata), antenna2 = antenna1:Nant(metadata)
        baseline_vector = metadata.positions[antenna1] - metadata.positions[antenna2]
        baseline_length = norm(baseline_vector)
        if baseline_length < minuvw * λ
            flags[α] = true
        end
        α += 1
    end
    flags
end

end

