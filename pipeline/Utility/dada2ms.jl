"""
    listdadas(spw, dataset)

Return a list of the path to every dada file from the given spectral window.
"""
function listdadas(spw, dataset)
    spw = fix_spw_offset(spw, dataset)
    str = @sprintf("%02d", spw)
    if dataset == "100hr"
        dir = "/lustre/data/2016-03-19_100hour_run"
        prefix = "2016-03-19-01:44:01"
    elseif dataset == "rainy"
        dir = "/lustre/data/2017-02-17_24hour_run"
        prefix = "2017-02-11-02:36:59"
    else
        dir = joinpath("/lustre/data", dataset)
        prefix = ""
    end
    files = readdir(joinpath(dir, str))
    filter!(files) do file
        startswith(file, prefix)
    end
    sort!(files)
    for idx = 1:length(files)
        files[idx] = joinpath(dir, str, files[idx])
    end
    files
end

# The rainy data is offset from the 100 hour run by one spectral window.
fix_spw_offset(spw, dataset) = dataset == "rainy"? spw - 1 : spw

function dada2ms_core(dada::AbstractString, ms, dataset)
    run(`dada2ms-mwe $dada $ms`)

    # swap mixed up polarizations
    dir = dirname(@__FILE__)
    cmd = joinpath(dir, "../swapped-polarization-fixes/swap-polarizations-$dataset")
    run(`$cmd $ms`)
end

function dada2ms_core(dada::Vector, ms, dataset)
    run(`dada2ms-mwe --onespw $dada $ms`)

    # swap mixed up polarizations
    dir = dirname(@__FILE__)
    cmd = joinpath(dir, "../swapped-polarization-fixes/swap-polarizations-$dataset")
    run(`$cmd $ms`)
end

function dada2ms(dada, dataset)
    isdir(tempdir) || mkdir(tempdir)
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

