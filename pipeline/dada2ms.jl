"""
    listdadas(spw, dataset="100hr")

Return a list of the path to every dada file from the given spectral window.
"""
function listdadas(spw, dataset="100hr")
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

# Data from the 100 hour run had a bug in the FPGA firmware coarse delays that ended up swapping the
# polarizations on some lines.
are_pols_swapped(dataset) = dataset == "100hr"

# The rainy data is offset from the 100 hour run by one spectral window.
fix_spw_offset(spw, dataset) = dataset == "rainy"? spw + 1 : spw

function dada2ms_core(dada::AbstractString, ms, swap_polarizations=true)
    if swap_polarizations
        run(`dada2ms-mwe $dada $ms`)
        run(`swap_polarizations_from_delay_bug $ms`)
    else
        run(`dada2ms-mwe $dada $ms`)
    end
end

function dada2ms_core(dada::Vector, ms, swap_polarizations=true)
    if swap_polarizations
        run(`dada2ms-mwe --onespw $dada $ms`)
        run(`swap_polarizations_from_delay_bug $ms`)
    else
        run(`dada2ms-mwe --onespw $dada $ms`)
    end
end

function dada2ms(dada; swap_polarizations=true)
    isdir(tempdir) || mkdir(tempdir)
    path = joinpath(tempdir, replace(basename(dada), "dada", "ms"))
    dada2ms_core(dada, path, swap_polarizations)
    Table(ascii(path)), path
end

function dada2ms(spw::Int, dada; swap_polarizations=true)
    output = replace(basename(dada), "dada", "ms")
    output = @sprintf("spw%02d-%s", spw, output)
    path = joinpath(tempdir, output)
    dada2ms_core(dada, path, swap_polarizations)
    Table(ascii(path)), path
end

