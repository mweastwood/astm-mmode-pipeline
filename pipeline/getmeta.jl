function getmeta(spw, dataset="100hr")
    dir = getdir(spw)
    file = joinpath(dir, "metadata-$dataset.jld")
    if isfile(file)
        meta = load(file, "metadata")
        return meta::Metadata
    else
        dadas = listdadas(spw, dataset)
        ms, path = dada2ms(dadas[1], dataset)
        meta = Metadata(ms)
        finalize(ms)
        rm(path, recursive=true)
        save(file, "metadata", meta)
        return meta::Metadata
    end
end

