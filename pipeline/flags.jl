function read_antenna_flags(filename)
    flags = readcsv(joinpath(workspace, "flags", filename), Int) + 1
    reshape(flags, length(flags))
end

function read_baseline_flags(filename)
    flags = readdlm(joinpath(workspace, "flags", filename), '&', Int) + 1
    flags
end

function read_channel_flags(filename, spw)
    flags = readdlm(joinpath(workspace, "flags", filename), ':', Int)
    keep = flags[:,1] .== spw
    flags[keep, 2] + 1
end

#function apply_gregg_flags!(flags)
#    coreflags_nosignal = [0,87,104,105,128,145,148,157,161,164,168,197,220,225]+1
#    coreflags_arxpickup = [6,7,14,15,69,73,74,75,76,77,78,79,80,81,82,83,84,85,86,89,90,91,92,93,94,95,135]+1
#    coreflags_gregg = [185,186,238,43,44,160,114,115,116,117,118]+1
#    expansionflags = [59,187,120]+1
#    ledaants = [246,247,248,249,250,251,252,253,254,255]+1
#    flag_antennas!(flags, coreflags_nosignal)
#    flag_antennas!(flags, coreflags_arxpickup)
#    flag_antennas!(flags, coreflags_gregg)
#    flag_antennas!(flags, expansionflags)
#    flag_antennas!(flags, ledaants)
#end

function apply_antenna_flags!(ms)
    flags = AntennaFlags(256)
    flag_antennas!(flags, read_antenna_flags("coreflags_arxpickup.ants"))
    flag_antennas!(flags, read_antenna_flags("coreflags_gregg.ants"))
    flag_antennas!(flags, read_antenna_flags("coreflags_nosignal.ants"))
    flag_antennas!(flags, read_antenna_flags("expansionflags.ants"))
    flag_antennas!(flags, read_antenna_flags("ledaants.ants"))
    flag_antennas!(flags, read_antenna_flags("flagsRyan.ants"))
    flag_antennas!(flags, read_antenna_flags("flagsMarin.ants"))
    #apply_gregg_flags!(flags)
    #flag_antennas!(flags, [73, 190, 211, 220, 225]) # spw04
    #flag_antennas!(flags, [177]) # spw18
    ## 8-2-2016 flags from 500 integration average on spw04
    #flag_antennas!(flags, [178, 222, 246])
    ## 9-21-2016 flags from integration 3000 on spw18
    #flag_antennas!(flags, [166, 167, 168])
    # spw18 trying to get Cas to peel on integration 1565
    #flag_antennas!(flags, [101, 102, 103, 104, 125, 127, 148])
    applyflags!(ms, flags)
    nothing
end

function flag_baseline!(flags, ant1, ant2)
    flags[baseline_index(ant1, ant2)] = true
end

function flag_baselines!(flags, filename)
    newflags = read_baseline_flags(filename)
    for α = 1:size(newflags, 1)
        flag_baseline!(flags, newflags[α, 1], newflags[α, 2])
    end
    newflags
end

function apply_baseline_flags!(ms)
    flags = zeros(Bool, (256*257)÷2)
    flag_baselines!(flags, "flagsRyan_adjacent.bl")
    flag_baselines!(flags, "flagsRyan_score.bl")
    flag_baselines!(flags, "flagsMarin.bl")

    ## Flag all the lines on adjacent ARX boards.
    ## Note that antennas 287 and 288 use ARX lines 247 and 248, but
    ## the correlator sees them as antennas 239 and 240.
    #remap = Dict(239 => 247, 240 => 248)
    #for ant1 = 1:256, ant2 = ant1:256
    #    line1 = get(remap, ant1, ant1)
    #    line2 = get(remap, ant2, ant2)
    #    if (line1-1) ÷ 8 == (line2-1) ÷ 8 && abs(line1-line2) ≤ 1
    #        α = baseline_index(ant1, ant2)
    #        baseline_flags[α] = true
    #    end
    #end
    #baseline_flags[baseline_index(191, 210)] = true

    ## 8-2-2016 flags from 500 integration average on spw04
    #@flagbl 57 128
    #@flagbl 57 240
    #@flagbl 58 64
    #@flagbl 58 185
    #@flagbl 58 192
    #@flagbl 58 243
    #@flagbl 59 64
    #@flagbl 59 128
    #@flagbl 59 215
    #@flagbl 63 215
    #@flagbl 64 127
    #@flagbl 64 128
    #@flagbl 64 192
    #@flagbl 64 240
    #@flagbl 123 215
    #@flagbl 125 215
    #@flagbl 126 240
    #@flagbl 127 240
    #@flagbl 128 178
    #@flagbl 128 192
    #@flagbl 128 243
    #@flagbl 192 240
    #@flagbl 192 243
    ## 9-21-2016 flags from integration 3000 on spw18
    #@flagbl 210 212

    row_flags = ms["FLAG_ROW"]
    for α = 1:length(row_flags)
        row_flags[α] = row_flags[α] || flags[α]
    end
    ms["FLAG_ROW"] = row_flags
    nothing
end

function apply_channel_flags!(ms, spw)
    flags = ChannelFlags(109, 256)
    flag_channels!(flags, read_channel_flags("ryan_fit.chans", spw))
    applyflags!(ms, flags)

    #if spw == 18
    #    flags = ChannelFlags(109, 256)
    #    flag_channels!(flags, [7, 11, 12])
    #    applyflags!(ms, flags)
    #end
end

function flag!(ms::Table, spw)
    clearflags!(ms)
    apply_antenna_flags!(ms)
    apply_baseline_flags!(ms)
    apply_channel_flags!(ms, spw)
    nothing
end

function aoflagger(path)
    readall(`aoflagger $path`)
    Table(ascii(path))
end

