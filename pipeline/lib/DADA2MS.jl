module DADA2MS

export dada2ms

using CasaCore.Tables

const tempdir = "/dev/shm/mweastwood"
const antfile = "/opt/astro/dada2ms/share/dada2ms/ant_positions_NAD83_fiber_mapping1.txt"

function dada2ms_core(dada::AbstractString, ms, dataset)
    run(`dada2ms-mwe --utmzone 11 --antfile $antfile $dada $ms`)

    # swap mixed up polarizations
    dir = dirname(@__FILE__)
    cmd = joinpath(dir, "../../swapped-polarization-fixes/swap-polarizations-$dataset")
    run(`$cmd $ms`)
end

function dada2ms_core(dada::Vector, ms, dataset)
    run(`dada2ms-mwe --utmzone 11 --antfile $antfile --onespw $dada $ms`)

    # swap mixed up polarizations
    dir = dirname(@__FILE__)
    cmd = joinpath(dir, "../../swapped-polarization-fixes/swap-polarizations-$dataset")
    run(`$cmd $ms`)
end

function dada2ms(dada, dataset)
    isdir(tempdir) || mkdir(tempdir)
    path = joinpath(tempdir, replace(basename(dada), "dada", "ms"))
    dada2ms_core(dada, path, dataset)
    Tables.open(ascii(path)), path
end

function dada2ms(spw::Int, dada, dataset)
    isdir(tempdir) || mkdir(tempdir)
    output = replace(basename(dada), "dada", "ms")
    output = @sprintf("spw%02d-%s", spw, output)
    path = joinpath(tempdir, output)
    dada2ms_core(dada, path, dataset)
    Tables.open(ascii(path)), path
end

end

