function postprocess(spw)
    #makemovie(spw)
end

function rfi_light_curves(spw)
    dir = getdir(spw)
    tmp = joinpath(dir, "tmp")
    files = readdir(tmp)
    filter!(files) do file
        startswith(file, "2016-03-19") && endswith(file, ".jld")
    end

    N = length(files)
    kernel(file) = load(joinpath(tmp, file), "rfi_flux") :: Vector{HermitianJonesMatrix}
    rfi_fluxes = pmap(kernel, files)

    M = length(rfi_fluxes[1])
    output = zeros(HermitianJonesMatrix, M, N)
    for idx = 1:N, jdx = 1:M
        output[jdx, idx] = rfi_fluxes[idx][jdx]
    end

    save(joinpath(dir, "rfi-light-curves.jld"), "light-curves", output)
    output
end

#=
function postprocess(spw)
    dir = getdir(spw)
    tmp = joinpath(dir, "tmp")
    files = readdir(tmp)

    # Make a movie out of the images
    Lumberjack.info("Creating a movie of the images from spectral window $spw")
    pngs = filter(files) do file
        endswith(file, ".png")
    end
    sort!(pngs)
    ffmpeg_input = joinpath(tmp, "ffmpeg-input.txt")
    file = open(ffmpeg_input, "w")
    for png in pngs
        path = joinpath(tmp, png)
        println(file, "file '$path'")
    end
    close(file)
    movie = joinpath(dir, "movie.mp4")
    isfile(movie) && rm(movie)
    run(`ffmpeg -f concat -i $ffmpeg_input -codec:v libx264 -profile:v high444 -preset slow -b:v 2000k -vf scale=-1:720 $movie`)
    rm(ffmpeg_input)
    for png in pngs
        path = joinpath(tmp, png)
        rm(path)
    end

    # Collate the source information
    Lumberjack.info("Collating the source information from $spw")
    jlds = filter(files) do file
        endswith(file, ".jld") && !startswith(file, "test")
    end
    sort!(jlds)
    meta = getmeta(spw)
    frame = TTCal.reference_frame(meta)
    times = load(joinpath(dir, "visibilities.jld"), "times")
    source_I = Dict()
    source_Q = Dict()
    source_az = Dict()
    source_el = Dict()
    p = Progress(length(jlds), "Progress: ")
    for idx = 1:length(jlds)
        time = times[idx]
        jld  =  jlds[idx]
        path = joinpath(tmp, jld)
        peeled_sources, subtracted_sources = load(path, "peeled-sources", "subtracted-sources")
        for source in [peeled_sources; subtracted_sources]
            name = source.name
            I, Q, az, el = flux_az_el(frame, time, source)
            if haskey(source_I, name)
                push!(source_I[name], I)
                push!(source_Q[name], Q)
                push!(source_az[name], az)
                push!(source_el[name], el)
            else
                source_I[name] = [I]
                source_Q[name] = [Q]
                source_az[name] = [az]
                source_el[name] = [el]
            end
        end
        next!(p)
    end
    for jld in jlds
        path = joinpath(tmp, jld)
        rm(path)
    end
    save(joinpath(dir, "source-information.jld"), "I", source_I, "Q", source_Q, "az", source_az, "el", source_el)

    nothing
end

function flux_az_el(frame, time, source)
    set!(frame, Epoch(epoch"UTC", time*seconds))
    I = source.spectrum.stokes.I
    Q = source.spectrum.stokes.Q
    j2000 = source.direction
    azel  = measure(frame, j2000, dir"AZEL")
    az = longitude(azel)
    el =  latitude(azel)
    I, Q, az, el
end
=#

