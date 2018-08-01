module Driver

using FileIO, JLD2
using ProgressMeter
using BPJSpec
using YAML

include("Project.jl")

struct Config
    input     :: String
    output    :: String
    hierarchy :: String
    gain_errors_percent  :: Float64
    same_across_antennas :: Bool
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["input"],
           dict["output"],
           dict["hierarchy"],
           dict["gain-errors-percent"],
           dict["same-across-antennas"])
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    mess_with_gains(project, config)
end

function mess_with_gains(project, config)
    ant1 = [ant1 for ant1 = 1:256 for ant2 = ant1:256]
    ant2 = [ant2 for ant1 = 1:256 for ant2 = ant1:256]
    hierarchy = Project.load(project, config.hierarchy, "hierarchy")

    path   = Project.workspace(project)
    input  = BPJSpec.load(joinpath(path, config.input))
    output = similar(input, SingleFile(joinpath(path, config.output)))

    if config.same_across_antennas
        mess_with_bandpass(input, output, hierarchy, config.gain_errors_percent)
    else
        mess_with_gains(input, output, ant1, ant2, hierarchy, config.gain_errors_percent)
    end
end

function mess_with_gains(input, output, ant1, ant2, hierarchy, gain_errors_percent)
    mmax  = input.mmax
    Nfreq = length(input.frequencies)

    g = complex.(randn(256, Nfreq), randn(256, Nfreq)) ./ √2
    g .*= gain_errors_percent / 100
    g .+= 1

    prg = Progress((mmax+1) * Nfreq)
    for m = 0:mmax
        permutation = BPJSpec.baseline_permutation(hierarchy, m)
        for β = 1:Nfreq
            block = input[m, β] :: Vector{Complex128}
            for α = 1:length(permutation)
                a1 = ant1[permutation[α]]
                a2 = ant2[permutation[α]]
                if m == 0
                    block[α] *= g[a1, β]*conj(g[a2, β])
                else
                    block[2α-1] *= g[a1, β]*conj(g[a2, β])
                    block[2α-0] *= g[a1, β]*conj(g[a2, β])
                end
            end
            output[m, β] = block
            next!(prg)
        end
    end
end

function mess_with_bandpass(input, output, hierarchy, gain_errors_percent)
    mmax  = input.mmax
    Nfreq = length(input.frequencies)

    g = complex.(randn(Nfreq), randn(Nfreq)) ./ √2
    g .*= gain_errors_percent / 100
    g .+= 1

    prg = Progress((mmax+1) * Nfreq)
    for m = 0:mmax
        permutation = BPJSpec.baseline_permutation(hierarchy, m)
        for β = 1:Nfreq
            block = input[m, β] :: Vector{Complex128}
            for α = 1:length(permutation)
                if m == 0
                    block[α] *= g[β]*conj(g[β])
                else
                    block[2α-1] *= g[β]*conj(g[β])
                    block[2α-0] *= g[β]*conj(g[β])
                end
            end
            output[m, β] = block
            next!(prg)
        end
    end
end

end

