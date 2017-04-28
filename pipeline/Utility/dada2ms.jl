const tempdir = "/dev/shm/mweastwood"

function dada2ms_core(dada::AbstractString, ms, dataset)
    run(`dada2ms-mwe $dada $ms`)

    # swap mixed up polarizations
    dir = dirname(@__FILE__)
    cmd = joinpath(dir, "../../swapped-polarization-fixes/swap-polarizations-$dataset")
    run(`$cmd $ms`)
end

function dada2ms_core(dada::Vector, ms, dataset)
    run(`dada2ms-mwe --onespw $dada $ms`)

    # swap mixed up polarizations
    dir = dirname(@__FILE__)
    cmd = joinpath(dir, "../../swapped-polarization-fixes/swap-polarizations-$dataset")
    run(`$cmd $ms`)
end

function dada2ms(dada, dataset)
    path = joinpath(tempdir, replace(basename(dada), "dada", "ms"))
    dada2ms_core(dada, path, dataset)
    Table(ascii(path)), path
end

function dada2ms(spw::Int, dada, dataset)
    output = replace(basename(dada), "dada", "ms")
    output = @sprintf("spw%02d-%s", spw, output)
    path = joinpath(tempdir, output)
    dada2ms_core(dada, path, dataset)
    Table(ascii(path)), path
end

