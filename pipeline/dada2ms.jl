"""
    listdadas(spw)

Return a list of the path to every dada file from the given spectral window.
"""
function listdadas(spw)
    str = @sprintf("%02d", spw)
    dir = "/lustre/data/2016-03-19_100hour_run"
    files = readdir(joinpath(dir, str))
    filter!(files) do file
        startswith(file, "2016-03-19-01:44:01")
    end
    sort!(files)
    for idx = 1:length(files)
        files[idx] = joinpath(dir, str, files[idx])
    end
    files
end

function dada2ms_core(dada::AbstractString, ms)
    run(`dada2ms-mwe $dada $ms`)
    run(`swap_polarizations_from_delay_bug $ms`)
end

function dada2ms_core(dada::Vector, ms)
    run(`dada2ms-mwe --onespw $dada $ms`)
    run(`swap_polarizations_from_delay_bug $ms`)
end

function dada2ms(dada)
    isdir(tempdir) || mkdir(tempdir)
    path = joinpath(tempdir, replace(basename(dada), "dada", "ms"))
    dada2ms_core(dada, path)
    Table(ascii(path)), path
end

function dada2ms(spw::Int, dada)
    output = replace(basename(dada), "dada", "ms")
    output = @sprintf("spw%02d-%s", spw, output)
    path = joinpath(tempdir, output)
    dada2ms_core(dada, path)
    Table(ascii(path)), path
end

