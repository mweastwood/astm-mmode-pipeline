module WSClean

using CasaCore.Tables
using CasaCore.Measures
using CasaCore.MeasurementSets
using TTCal
using Unitful
#using FITSIO
using YAML

include("Project.jl")

struct Config
    weight :: String
    minuvw :: Float64
    j :: Int
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["weight"], dict["minuvw"], dict["j"])
end

function run(config::Config, input::TTCal.Dataset, output)
    path = joinpath(Project.temp(), randstring(4)*".ms")
    ms = MeasurementSets.create(path)
    Tables.add_rows!(ms, Nbase(input))
    TTCal.write(ms, input, column="DATA")

    fill_main_table!(ms, input.metadata)
    fill_antenna_table!(ms, input.metadata)
    fill_data_description_table!(ms, input.metadata)
    fill_feed_table!(ms, input.metadata)
    fill_field_table!(ms, input.metadata)
    fill_polarization_table!(ms, input.metadata)
    fill_spectral_window_table!(ms, input.metadata)

    Tables.close(ms)
    run(config, ms, output)
    Tables.delete(ms)
end

function fill_main_table!(ms, metadata)
    time = fill(metadata.times[1].time, Nbase(metadata))
    ms["TIME"] = time
    ms["TIME_CENTROID"] = time

    antenna1 = zeros(Int32, Nbase(metadata))
    antenna2 = zeros(Int32, Nbase(metadata))
    α = 1
    for ant1 = 1:Nant(metadata), ant2 = ant1:Nant(metadata)
        antenna1[α] = ant1-1
        antenna2[α] = ant2-1
        α += 1
    end
    ms["ANTENNA1"] = antenna1
    ms["ANTENNA2"] = antenna2

    frame = ReferenceFrame(metadata)
    up    = measure(frame, metadata.phase_centers[1], dir"ITRF")
    north = measure(frame, Direction(dir"J2000", 0, 0, 1), dir"ITRF")
    north = Direction(north - dot(up, north)*up)
    east  = cross(north, up)
    uvw = zeros(3, Nbase(metadata))
    for α = 1:Nbase(metadata)
        r1 = metadata.positions[antenna1[α]+1]
        r2 = metadata.positions[antenna2[α]+1]
        Δr = Baseline(baseline"ITRF", r1.x-r2.x, r1.y-r2.y, r1.z-r2.z)
        uvw[1, α] = ustrip(dot(Δr, east))
        uvw[2, α] = ustrip(dot(Δr, north))
        uvw[3, α] = ustrip(dot(Δr, up))
    end
    ms["UVW"] = uvw

    ms["DATA_DESC_ID"] = zeros(Int32, Nbase(metadata))
    ms["WEIGHT"] = ones(Float32, 4, Nbase(metadata))
    ms["SIGMA"] = ones(Float32, 4, Nbase(metadata))
    ms["SCAN_NUMBER"] = ones(Int32, Nbase(metadata))

end

function fill_antenna_table!(ms, metadata)
    table = ms[kw"ANTENNA"]
    Tables.add_rows!(table, Nant(metadata))
    table["NAME"] = [@sprintf("ANT%03d", ant) for ant = 1:Nant(metadata)]
    table["STATION"] = fill("OVRO-LWA", Nant(metadata))
    table["TYPE"] = fill("GROUND-BASED", Nant(metadata))
    table["MOUNT"] = fill("X-Y", Nant(metadata))
    table["OFFSET"] = zeros(3, Nant(metadata))
    table["DISH_DIAMETER"] = fill(2.0, Nant(metadata))
    positions = zeros(3, Nant(metadata))
    for ant = 1:Nant(metadata)
        positions[1, ant] = metadata.positions[ant].x
        positions[2, ant] = metadata.positions[ant].y
        positions[3, ant] = metadata.positions[ant].z
    end
    table["POSITION"] = positions
    Tables.close(table)
end

function fill_data_description_table!(ms, metadata)
    table = ms[kw"DATA_DESCRIPTION"]
    Tables.add_rows!(table, 1)
    table["FLAG_ROW"] = [false]
    table["POLARIZATION_ID"] = Int32[0]
    table["SPECTRAL_WINDOW_ID"] = Int32[0]
    Tables.close(table)
end

function fill_feed_table!(ms, metadata)
    table = ms[kw"FEED"]
    Tables.add_rows!(table, Nant(metadata))
    Tables.close(table)
end

function fill_field_table!(ms, metadata)
    table = ms[kw"FIELD"]
    Tables.add_rows!(table, 1)
    frame = ReferenceFrame(metadata)
    dir = measure(frame, metadata.phase_centers[1], dir"J2000")
    longlat = ustrip.([longitude(dir), latitude(dir)])
    table["DELAY_DIR"] = reshape(longlat, 2, 1, 1)
    table["PHASE_DIR"] = reshape(longlat, 2, 1, 1)
    table["REFERENCE_DIR"] = reshape(longlat, 2, 1, 1)
    table["NAME"] = ["zenith"]
    Tables.close(table)
end

function fill_polarization_table!(ms, metadata)
    table = ms[kw"POLARIZATION"]
    Tables.add_rows!(table, 1)
    table["CORR_TYPE"] = reshape(Int32[9, 10, 11, 12], 4, 1)
    table["CORR_PRODUCT"] = reshape(Int32[0 0 1 1; 0 1 0 1], 2, 4, 1)
    table["NUM_CORR"] = Int32[4]
    Tables.close(table)
end

function fill_spectral_window_table!(ms, metadata)
    table = ms[kw"SPECTRAL_WINDOW"]
    Tables.add_rows!(table, 1)
    table["MEAS_FREQ_REF"] = Int32[1]
    ν = ustrip.(uconvert.(u"Hz", metadata.frequencies))
    Δν = ν[2] - ν[1]
    table["CHAN_FREQ"] = reshape(ν, Nfreq(metadata), 1)
    table["REF_FREQUENCY"] = [ν[1] - Δν/2]
    table["CHAN_WIDTH"] = fill(Δν, Nfreq(metadata), 1)
    table["EFFECTIVE_BW"] = fill(Δν, Nfreq(metadata), 1)
    table["RESOLUTION"] = fill(Δν, Nfreq(metadata), 1)
    table["FLAG_ROW"] = [false]
    table["FREQ_GROUP"] = Int32[0]
    table["FREQ_GROUP_NAME"] = ["Group 1"]
    table["IF_CONV_CHAIN"] = Int32[0]
    table["NAME"] = ["subband"]
    table["NET_SIDEBAND"] = Int32[1]
    table["NUM_CHAN"] = Int32[Nfreq(metadata)]
    table["TOTAL_BANDWIDTH"] = [Δν*Nfreq(metadata)]
    Tables.close(table)
end

function run(config::Config, input::Table, output)
    Tables.close(input)
    readstring(`wsclean -j $(config.j) -size 2048 2048 -scale 0.0625
                        -weight $(config.weight) -minuv-l $(config.minuvw)
                        -name $output $(input.path)`)
    image_name = output*"-image.fits"
    dirty_name = output*"-dirty.fits"
    rm(dirty_name)
    mv(image_name, output*".fits", remove_destination=true)
    output*".fits"
end

#function fits2png(input, output, lower_limit=-300, upper_limit=+800)
#    fits = FITS(input*".fits")
#    img = read(fits[1])[:,:,1,1]
#    img -= lower_limit
#    img /= upper_limit - lower_limit
#    img = clamp(img, 0, 1)
#    img = flipdim(img', 1)
#    save(output, img)
#end

end

