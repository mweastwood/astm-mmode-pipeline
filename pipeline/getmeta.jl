function getmeta(spw)
    dir = getdir(spw)
    file = joinpath(dir, "metadata.jld")
    if isfile(file)
        meta = load(file, "metadata")
        return meta::Metadata
    else
        dadas = listdadas(spw)
        ms, path = dada2ms(dadas[1])
        meta = Metadata(ms)
        finalize(ms)
        rm(path, recursive=true)
        save(file, "metadata", meta)
        return meta::Metadata
    end
end

