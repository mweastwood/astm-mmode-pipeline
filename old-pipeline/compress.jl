function compress_images(spw, prefix="cyg-")
    dir = getdir(spw)
    dir = joinpath(dir, "tmp")
    files = readdir(dir)
    filter!(file -> startswith(file, prefix) && endswith(file, ".png"), files)
    N = length(files)

    range = 1:100
    next_range() = (myrange = range; range += 100; myrange)

    @sync for worker in workers()
        @async while true
            myrange = next_range()
            if myrange[1] > N
                break
            end
            if myrange[end] > N
                myrange = myrange[1]:N
            end
            myfiles = files[myrange]
            remotecall_fetch(compress_images, worker, spw, prefix, myrange, myfiles)
        end
    end
end

function compress_images(spw, prefix, myrange, myfiles)
    dir = getdir(spw)
    dir = joinpath(dir, "tmp")
    output = prefix * @sprintf("images-%05d.tar.gz", myrange[1])
    cd(dir)
    readstring(`tar -czvf $output $myfiles`)
    for file in myfiles
        rm(file)
    end
end

