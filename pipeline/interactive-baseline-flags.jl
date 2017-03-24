function interactive_baseline_flags_setup(spws, filename)
    xx = Dict{Int, Vector{Complex128}}()
    yy = Dict{Int, Vector{Complex128}}()
    flags = Dict{Int, Vector{Bool}}()
    for spw in spws
        dir = getdir(spw)
        mydata, myflags = load(joinpath(dir, filename*".jld"), "data", "flags")
        summed_mydata = squeeze(sum(mydata, 3), 3)
        summed_myflags = squeeze(all(myflags, 2), 2)
        xx[spw] = summed_mydata[1, :]
        yy[spw] = summed_mydata[2, :]
        flags[spw] = summed_myflags
    end
    b = getbaselinelengths()
    xx, yy, flags, b
end

function interactive_baseline_flags_setup(spws, filename, direction)
    xx = Dict{Int, Vector{Complex128}}()
    yy = Dict{Int, Vector{Complex128}}()
    flags = Dict{Int, Vector{Bool}}()
    for spw in spws
        dir = getdir(spw)
        meta = getmeta(spw)
        mytimes, mydata, myflags = load(joinpath(dir, filename*".jld"), "times", "data", "flags")
        _xx, _yy, _flags = sum_with_new_phase_center(spw, mytimes, mydata, myflags, direction)
        xx[spw] = _xx
        yy[spw] = _yy
        flags[spw] = _flags
    end
    b = getbaselinelengths()
    xx, yy, flags, b
end

function sum_with_new_phase_center(spw, times, data, flags, direction)
    meta = getmeta(spw)
    meta.channels = meta.channels[55:55]
    meta.phase_center = Direction(dir"AZEL", 0degrees, 90degrees)
    center = PointSource("phase center", direction, PowerLaw(1, 0, 0, 0, 1e6, [0.0]))

    _, Nbase, Ntime = size(data)
    output_xx = zeros(Complex128, Nbase)
    output_yy = zeros(Complex128, Nbase)
    output_flags = ones(Bool, Nbase)
    for idx = 1:Ntime
        meta.time = Epoch(epoch"UTC", times[idx]*seconds)
        frame = TTCal.reference_frame(meta)
        if TTCal.isabovehorizon(frame, center)
            model = genvis(meta, [center])
            for α = 1:Nbase
                if !flags[α, idx]
                    xx = data[1, α, idx]
                    yy = data[2, α, idx]
                    J = JonesMatrix(xx, 0, 0, yy)
                    J /= model.data[α, 1]
                    output_xx[α] += J.xx
                    output_yy[α] += J.yy
                    output_flags[α] = false
                end
            end
        end
    end
    output_xx, output_yy, output_flags
end

function interactive_baseline_flags_plot(spws, xx, yy, flags, b)
    figure(1); clf()
    xrange = (0, 1500)
    yrange = (0, 0)
    for spw in spws
        f = flags[spw]
        f = f | (b.==0)
        x = abs(xx[spw][!f])
        y = abs(yy[spw][!f])
        c = spw*ones(sum(!f))
        scatter(b[!f], x, c=c, s=20, lw=1, cmap=get_cmap("gist_rainbow"), vmin=4, vmax=18)
        scatter(b[!f], y, c=c, s=20, lw=1, cmap=get_cmap("gist_rainbow"), vmin=4, vmax=18)
        yrange = (0, max(yrange[2], maximum(x), maximum(y)))
    end
    xlim(xrange[1], xrange[2])
    ylim(yrange[1], yrange[2])
    colorbar()
    grid("on")
    tight_layout()

    meta = getmeta(4)
    ant1 = getfield.(meta.baselines, 1)
    ant2 = getfield.(meta.baselines, 2)
    function find_nearest(xcoord, ycoord)
        xcoord === nothing && return
        ycoord === nothing && return
        nearest_spw = 0
        nearest_pol = ""
        nearest_ant1 = 0
        nearest_ant2 = 0
        nearest_distance = Inf
        for spw in spws
            f = flags[spw]
            f = f | (b.==0)
            x = abs(xx[spw][!f])
            y = abs(yy[spw][!f])
            xdistance = hypot((b[!f]-xcoord)/xrange[2], (x-ycoord)/yrange[2])
            ydistance = hypot((b[!f]-xcoord)/xrange[2], (y-ycoord)/yrange[2])
            xidx = indmin(xdistance)
            yidx = indmin(ydistance)
            if xdistance[xidx] < nearest_distance
                nearest_distance = xdistance[xidx]
                nearest_spw = spw
                nearest_pol = "X"
                nearest_ant1 = ant1[!f][xidx]
                nearest_ant2 = ant2[!f][xidx]
            end
            if ydistance[yidx] < nearest_distance
                nearest_distance = ydistance[yidx]
                nearest_spw = spw
                nearest_pol = "Y"
                nearest_ant1 = ant1[!f][yidx]
                nearest_ant2 = ant2[!f][yidx]
            end
        end
        @printf("@ spw%02d %d&%d\n", nearest_spw, nearest_ant1, nearest_ant2)
    end

    function process_event(event)
        if event[:key] == "i"
            find_nearest(event[:xdata], event[:ydata])
        end
    end
    gcf()[:canvas][:mpl_connect]("button_press_event", process_event)
    show()

    nothing
end

function getbaselinelengths()
    meta = getmeta(4)
    b = zeros(Nbase(meta))
    for ant1 = 1:256, ant2 = ant1:256
        u = meta.antennas[ant1].position.x - meta.antennas[ant2].position.x
        v = meta.antennas[ant1].position.y - meta.antennas[ant2].position.y
        w = meta.antennas[ant1].position.z - meta.antennas[ant2].position.z
        α = baseline_index(ant1, ant2)
        b[α] = sqrt(u^2 + v^2 + w^2)
    end
    b
end

