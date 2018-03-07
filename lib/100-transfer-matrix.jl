module Driver

using BPJSpec
using CasaCore.Measures
using Cubature
using FileIO, JLD2
using TTCal
using YAML

include("Project.jl")

struct Config
    input  :: String
    output :: String
    coeff  :: Vector{Float64}
    lmax   :: Int
end

function load(file)
    dict = YAML.load(open(file))
    # TODO: allow lmax to be computed from the maximum baseline length
    Config(dict["input"], dict["output"], dict["coeff"], dict["lmax"])
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    transfermatrix(project, config)
    Project.touch(project, config.output)
end

function transfermatrix(project, config; simulation="")
    path = Project.workspace(project)
    ttcal_metadata = FileIO.load(joinpath(path, config.input*".jld2"), "metadata")
    frame = ReferenceFrame(ttcal_metadata)
    ttcal_metadata.phase_centers[1] = measure(frame, ttcal_metadata.phase_centers[1], dir"ITRF")
    if simulation != ""
        positions = simulate(simulation, ttcal_metadata)
        resize!(ttcal_metadata.positions, length(positions))
        ttcal_metadata.positions[:] = positions
    end
    bpjspec_metadata = BPJSpec.from_ttcal(ttcal_metadata)

    threshold = deg2rad(10)
    function beam_model(azimuth, elevation)
        beam(config.coeff, threshold, azimuth, elevation)
    end

    Ω, err = hcubature(x -> beam_model(x[1], x[2])*cos(x[2]), [0, 0], [2π, π/2])
    @show Ω

    transfermatrix = BPJSpec.HierarchicalTransferMatrix(joinpath(path, config.output),
                                                        bpjspec_metadata, lmax=config.lmax)
    BPJSpec.compute!(transfermatrix, beam_model)
end

function beam(coeff, threshold, azimuth, elevation)
    elevation < 0 && return 0.0
    ρ = cos(elevation)
    θ = azimuth
    amplitude = (coeff[1]*TTCal.zernike(0, 0, ρ, θ)
                + coeff[2]*TTCal.zernike(2, 0, ρ, θ)
                + coeff[3]*TTCal.zernike(4, 0, ρ, θ)
                + coeff[4]*TTCal.zernike(4, 4, ρ, θ)
                + coeff[5]*TTCal.zernike(6, 0, ρ, θ)
                + coeff[6]*TTCal.zernike(6, 4, ρ, θ)
                + coeff[7]*TTCal.zernike(8, 0, ρ, θ)
                + coeff[8]*TTCal.zernike(8, 4, ρ, θ)
                + coeff[9]*TTCal.zernike(8, 8, ρ, θ))
    if elevation < threshold
        # Shaping function from http://www.flong.com/texts/code/shapers_poly/
        x = elevation/threshold
        shape = 4/9*x^6 - 17/9*x^4 + 22/9*x^2
        amplitude *= shape
    end
    amplitude
end

function simulate(name, metadata)
    position = mean(metadata.positions)
    up = Direction(position)
    north = Direction(dir"ITRF", 0, 0, 1)
    north = Direction(north - dot(up, north)*up)
    east  = Direction(cross(north, up))
    if name == "hex"
        x, y = hex(9, 12) # 217 antennas with 12 m spacing
        positions = [Position(pos"ITRF", position.x + x[i]*east.x + y[i]*north.x,
                                         position.y + x[i]*east.y + y[i]*north.y,
                                         position.z + x[i]*east.z + y[i]*north.z)
                     for i = 1:length(x)]
    end
    positions
end

"Create a hex of antenna positions for a simulated redundant configuration."
function hex(n, spacing)
    N = 2*n - 1
    x = Float64[]
    y = Float64[]
    for row = 1:n
        M = N - row + 1 # number of antennas in this row
        x′ = collect(1:M) .* spacing
        x  = [x; x′ - mean(x′)]
        y  = [y; fill(√3*(row-1)/2*spacing, M)]
        if row > 1
            x  = [x; x′ - mean(x′)]
            y  = [y; fill(-√3*(row-1)/2*spacing, M)]
        end
    end
    x, y
end

end

