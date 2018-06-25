module Driver

using ProgressMeter
using TTCal
using BPJSpec
using Unitful
using YAML

include("Project.jl")

struct Config
    input    :: String
    output   :: String
    metadata :: String
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["input"],
           dict["output"],
           dict["metadata"])
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    sefd(project, config)
end

function sefd(project, config)
    path     = Project.workspace(project)
    input    = BPJSpec.load(joinpath(path, config.input))
    metadata = Project.load(project, config.metadata, "metadata")
    output   = zeros(Nfreq(metadata)-2, Ntime(metadata)-2)

    queue = collect(2:Ntime(metadata)-1)
    lck = ReentrantLock()
    prg = Progress(length(queue))
    increment() = (lock(lck); next!(prg); unlock(lck))

    @sync for worker in workers()
        @async while length(queue) > 0
            integration = shift!(queue)
            output[:, integration-1] = remotecall_fetch(measure_sefd, worker, input, integration)
            increment()
        end
    end

    Project.save(project, config.output, "SEFD", output)
end

function measure_sefd(input, integration)
    V1 = input[integration - 1]
    V2 = input[integration + 0]
    V3 = input[integration + 1]
    _measure_sefd(V1, V2, V3)
end

function _measure_sefd(V1, V2, V3)
    Δ = difference_all(V1, V2, V3)
    # for just the real or imaginary component of the visibilities, you get an additional factor of
    # two here (ie. N = 2×Δν×τ)
    N = uconvert(NoUnits, 24u"kHz"*13u"s")
    [sqrt(N)*rms(@view(Δ[:, β])) for β = 1:size(Δ, 2)]
end

"compute the RMS without counting zero elements"
function rms(x)
    S = mapreduce(           abs2, +, x)
    N = mapreduce(y -> !iszero(y), +, x)
    ifelse(N == 0, zero(typeof(S)), sqrt(S / N))
end

"xx and yy are 3x3 matrices (3 frequency channels x 3 time integrations)"
function difference_all_33(xx, yy)
    if any(xx .== 0) || any(yy .== 0)
        # punt if we're missing any data
        return zero(eltype(xx))
    else
        Δxx = 4xx[2, 2] - (xx[1, 1] + xx[1, 3] + xx[3, 1] + xx[3, 3])
        Δyy = 4yy[2, 2] - (yy[1, 1] + yy[1, 3] + yy[3, 1] + yy[3, 3])
        Δ = Δxx - Δyy
        # following the rules of error propagation, the standard deviation of the difference is
        #     (new σ) = √(4² + 4 + 4² + 4) × (old σ)
        # so we will scale the result so that the standard deviation remains unchanged
        return Δ / √40
    end
end

"V1, V2, and V3 are 2 × Nfreq × Nbase matrices from three separate integrations."
function difference_all(V1, V2, V3)
    _, Nfreq, Nbase = size(V1)
    output = zeros(eltype(V1), Nbase, Nfreq - 2)
    for α = 1:Nbase, β = 2:Nfreq-1
        xx = [V1[1, β-1, α] V1[1, β+0, α] V1[1, β+1, α]
              V2[1, β-1, α] V2[1, β+0, α] V2[1, β+1, α]
              V3[1, β-1, α] V3[1, β+0, α] V3[1, β+1, α]]
        yy = [V1[2, β-1, α] V1[2, β+0, α] V1[2, β+1, α]
              V2[2, β-1, α] V2[2, β+0, α] V2[2, β+1, α]
              V3[2, β-1, α] V3[2, β+0, α] V3[2, β+1, α]]
        output[α, β-1] = difference_all_33(xx, yy)
    end
    output
end

end

