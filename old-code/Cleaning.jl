module Cleaning

using CleaningWorkers

using CasaCore.Measures
using CasaCore.Tables
using TTCal
using BPJSpec
using LibHealpix
using JLD

const lmax = 1000
const mmax = 1000
const nside = 1024

function set_blas_threads()
    # compensate for a bug in addprocs
    @everywhere Base.blas_set_num_threads(16)
end

"""
    distribute_workload(mmax)

Determine which worker is going to process each value of `m`.
"""
function distribute_workload(mmax)
    N = nprocs()
    responsibilities = Vector{Int}[]
    for worker = 1:N
        push!(responsibilities, Int[])
    end

    m = 0
    pattern = [2:N; N:-1:2]
    for worker in cycle(pattern)
        push!(responsibilities[worker], m)
        if m ≥ mmax
            return responsibilities
        end
        m += 1
    end
end

"""
    load(responsibilities)

Tell each worker to load its transfer matrix blocks and m-mode blocks.
"""
function load(responsibilities)
    @sync for worker in workers()
        @async begin
            remotecall_fetch(worker, give_responsibilities, responsibilities[worker])
            remotecall_fetch(worker, load_transfermatrix)
            remotecall_fetch(worker, load_mmodes)
            println("Worker $worker has finished loading.")
        end
    end
end

"""
    genpsf()

Generate a Healpix image of the PSF at various declinations.
Note that we will also step the right ascension in order to try and
prevent the PSFs from overlapping.
"""
function genpsf()
    responsibilities = distribute_workload(mmax)
    #load(responsibilities)

    N = 18
    θ = linspace(0,  π, N)
    ϕ = linspace(0, 2π, N)
    flux = ones(N)
    #=
    alm = Alm(Complex128, lmax, mmax)
    @time @sync for worker in workers()
        @async begin
            myalm = remotecall_fetch(worker, run_observe, flux, θ, ϕ)
            for (idx,m) in enumerate(responsibilities[worker])
                for l = m:lmax
                    alm[l,m] = myalm[idx][l-m+1]
                end
            end
            println("Worker $worker has finished observing the PSF.")
        end
    end

    map = alm2map(alm, 1024)
    writehealpix("cleaning-tests/psf.fits", map)
    =#

    map = readhealpix("cleaning-tests/psf.fits")
    peak = zeros(N)
    for idx = 1:N
        peak[idx] = map[θ[idx], ϕ[idx]]
    end

    writedlm("cleaning-tests/psf.txt", [θ peak])
end

function psf(θ)
    data  = readdlm("cleaning-tests/psf.txt")
    θlist = data[:,1]
    peak  = data[:,2]
    idx1 = searchsortedlast(θlist, θ)
    idx2 = idx1+1
    weight1 = θlist[idx2] - θ
    weight2 = θ - θlist[idx1]
    out = (weight1*peak[idx1] + weight2*peak[idx2]) / (weight1+weight2)
    out
end

"""
    image()

Instruct each worker to solve for the spherical harmonic coefficients.
"""
function image()
    set_blas_threads()
    responsibilities = distribute_workload(mmax)
    load(responsibilities)
    alm = Alm(Complex128, lmax, mmax)
    @sync for worker in workers()
        @async begin
            myalm = remotecall_fetch(worker, run_tikhonov)
            for (idx,m) in enumerate(responsibilities[worker])
                for l = m:lmax
                    alm[l,m] = myalm[idx][l-m+1]
                end
            end
            println("Worker $worker has finished solving.")
        end
    end
    alm
end

"""
    cleaning_regions()

Pick the directions for cleaning and return the unit vector towards each direction.
"""
function cleaning_regions()
    ms = Table("workspace/calibrations/day1.ms")
    meta = collect_metadata(ms, ConstantBeam())
    frame = TTCal.reference_frame(meta)
    unlock(ms)

    directions = Direction[]
    push!(directions, Direction(dir"J2000", "03h19m48.16010s", "+41d30m42.1031s")) # Per A
    push!(directions, Direction(dir"J2000", "05h04m42.0s", "+38d06m02s")) # 3C 134
    push!(directions, Direction(dir"J2000", "20h14m27.6s", "+23d34m53s")) # 3C 409

    N = length(directions)
    x = zeros(N)
    y = zeros(N)
    z = zeros(N)
    for idx = 1:N
        itrf = measure(frame, directions[idx], dir"ITRF")
        x[idx] = itrf.x
        y[idx] = itrf.y
        z[idx] = itrf.z
    end
    x, y, z
end

doc"""
    create_unit_vector_maps(nside)

This function will create 3 Healpix maps:

* A map of $\hat{x}$ to each pixel
* A map of $\hat{y}$ to each pixel
* A map of $\hat{z}$ to each pixel
"""
function create_unit_vector_maps(nside)
    x = HealpixMap(Float64, nside)
    y = HealpixMap(Float64, nside)
    z = HealpixMap(Float64, nside)
    for idx = 1:length(x)
        vec = LibHealpix.pix2vec_ring(nside, idx)
        x[idx] = vec[1]
        y[idx] = vec[2]
        z[idx] = vec[3]
    end
    x, y, z
end

const healpix_coords = create_unit_vector_maps(nside)

function measure_source_properties(map, x, y, z)
    healpix_x = healpix_coords[1]
    healpix_y = healpix_coords[2]
    healpix_z = healpix_coords[3]

    aperture = Int[]
    annulus = Int[]
    for idx = 1:length(healpix_x)
        dotproduct = healpix_x[idx]*x + healpix_y[idx]*y + healpix_z[idx]*z
        angle = acosd(dotproduct)
        if angle < 0.25
            push!(aperture, idx)
        elseif 3 < angle < 5
            push!(annulus, idx)
        end
    end

    pixels = Float64[]
    for idx in annulus
        push!(pixels, map[idx])
    end
    background = median(pixels)

    flux = 0.0
    component_x = 0.0
    component_y = 0.0
    component_z = 0.0
    for idx in aperture
        pixel = map[idx] - background
        if abs(pixel) > flux
            flux = pixel
            component_x = healpix_x[idx]
            component_y = healpix_y[idx]
            component_z = healpix_z[idx]
        end
    end

    # TODO: check to make sure the centroid is sensible
    norm = hypot(component_x, hypot(component_y, component_z))
    component_x /= norm
    component_y /= norm
    component_z /= norm
    θ = acos(component_z)
    ϕ = atan2(component_y, component_x)
    flux /= psf(θ)

    flux, θ, ϕ
end

function measure_source_properties(map)
    xlist, ylist, zlist = cleaning_regions()
    fluxlist = Float64[]
    θlist = Float64[]
    ϕlist = Float64[]
    for (x, y, z) in zip(xlist, ylist, zlist)
        flux, θ, ϕ = measure_source_properties(map, x, y, z)
        push!(fluxlist, flux)
        push!(θlist, θ)
        push!(ϕlist, ϕ)
    end
    fluxlist, θlist, ϕlist
end

function clean()
    λ = 0.15
    N = 20

    set_blas_threads()
    responsibilities = distribute_workload(mmax)
    load(responsibilities)
    alm = image()

    for idx = 1:N
        println("Starting clean iteration $idx")
        map = alm2map(alm, nside)
        save("cleaning-tests/alm-$(idx-1).jld", "alm", alm)
        writehealpix("cleaning-tests/cleaned-$(idx-1).fits", map, replace=true)

        flux, θ, ϕ = measure_source_properties(map)
        @show flux
        @show θ
        @show ϕ
        flux *= λ

        @time @sync for worker in workers()
            @async begin
                myalm = remotecall_fetch(worker, run_observe, flux, θ, ϕ)
                for (idx,m) in enumerate(responsibilities[worker])
                    for l = m:lmax
                        alm[l,m] -= myalm[idx][l-m+1]
                    end
                end
                println("Worker $worker has finished cleaning.")
            end
        end
    end

    map = alm2map(alm, nside)
    save("cleaning-tests/alm.jld", "alm", alm)
    writehealpix("cleaning-tests/cleaned.fits", map, replace=true)

    nothing
end

function subtract()
    map1 = readhealpix("cleaning-tests/map.fits")
    map2 = readhealpix("cleaning-tests/test-observed.fits")
    map3 = map1 - map2
    writehealpix("cleaning-tests/subtracted.fits", map3)
end

end

