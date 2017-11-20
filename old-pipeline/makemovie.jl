function makemovie(spw)
    Lumberjack.info("Creating a movie of the images from spectral window $spw")
    dir = getdir(spw)
    tmp = joinpath(dir, "tmp")
    files = readdir(tmp)
    pngs = filter(file -> startswith(file, "2016-03-19") && endswith(file, ".png"), files)
    pngs = sort(pngs)
    pngs = [joinpath(tmp, png) for png in pngs]
    pngs = makemovie_addtext(pngs)
    makemovie_ffmpeg(spw, pngs)
end

function makemovie_addtext(pngs)
    Lumberjack.info("Adding caption to each image")
    N = length(pngs)

    idx = 1
    nextidx() = (myidx = idx; idx += 1; myidx)

    p = Progress(N, "Progress: ")
    l = ReentrantLock()
    increment_progress() = (lock(l); next!(p); unlock(l))

    newpngs = UTF8String[]
    @sync for worker in workers()
        @async while true
            myidx = nextidx()
            myidx ≤ N || break
            png = pngs[myidx]
            text = @sprintf("%05d", myidx)
            output = remotecall_fetch(worker, makemovie_addtext_worker, png, text)
            push!(newpngs, output)
            increment_progress()
        end
    end
    sort!(newpngs)
    newpngs
end

function makemovie_addtext_worker(png, text)
    input = png
    output = joinpath(dirname(input), text*".png")
    run(`convert $input -gravity South -pointsize 50 -stroke black -strokewidth 5 -annotate 0 $text -stroke none -fill white -annotate 0 $text $output`)
    output
end

function makemovie_ffmpeg(spw, pngs)
    Lumberjack.info("Running ffmpeg")
    dir = getdir(spw)
    tmp = joinpath(dir, "tmp")
    ffmpeg_input = joinpath(tmp, "ffmpeg-input.txt")
    file = open(ffmpeg_input, "w")
    for png in pngs
        println(file, "file '$png'")
    end
    close(file)
    movie = joinpath(dir, "movie.mp4")
    isfile(movie) && rm(movie)
    run(`ffmpeg -f concat -i $ffmpeg_input -codec:v libx264 -profile:v high444 -preset slow -b:v 2000k -vf scale=-1:720 $movie`)
    rm(ffmpeg_input)
    for png in pngs
        rm(png)
    end
end

