module Driver

using CasaCore.Measures
using JLD2
using ProgressMeter
using TTCal
using Unitful

include("../lib/Common.jl");  using .Common

function calibrate(spw, dataset)
    path = getdir(spw, dataset)
    jldopen(joinpath(path, "raw-visibilities.jld2"), "r") do file
        baseline_flags = file["baseline-flags"]
        solve_for_gain_calibration(file, baseline_flags)
    end
end

function solve_for_gain_calibration(file, baseline_flags)
    println("Reading the dataset.")
    @time dataset = create_dataset_all_time(file, baseline_flags, 1600:1700)
    println("Create model dataset.")
end







function create_dataset_all_time(file, baseline_flags, indices)
    dataset = create_dataset_one_time(file, baseline_flags, indices[1])
    for index in indices[2:end]
        new_dataset = create_dataset_one_time(file, baseline_flags, index)
        TTCal.merge!(dataset, new_dataset, axis=:time)
    end
    dataset
end

function create_dataset_one_time(file, baseline_flags, index)
    data     = file[@sprintf("%06d",          index)]
    metadata = file[@sprintf("%06d-metadata", index)]
    function create(channel)
        visibilities = TTCal.SinglePolarizationVisibilities(Nant(metadata))
        for ant1 = 1:Nant(metadata), ant2 = ant1:Nant(metadata)
            α = baseline_index(ant1, ant2)
            if !baseline_flags[α]
                visibilities[ant1, ant2] = data[1, channel, α]
            end
        end
        visibilities
    end
    channels = 1:length(metadata.frequencies)
    visibilities = reshape(create.(channels), (length(channels), 1))
    TTCal.Dataset(metadata, visibilities)
end



#"""
#    solve_for_gain_calibration(spw, dataset, times data, flags, range)
#
#Solve for the gain calibration of the given data. We will take a large track of data in order to
#mitigate the effect of unmodeled sky components on the gain calibration.
#"""
#function solve_for_gain_calibration(spw, dataset, times, data, flags, range)
#    Ntime = length(range)
#    Nbase = size(data, 2)
#    Nant = Nbase2Nant(Nbase)
#
#    # TTCal currently doesn't natively support using multiple integrations to solve for the gain
#    # calibration. However it does support using multiple frequency channels. So we will use a hack
#    # to get this working.
#
#    measured = Visibilities(Nbase, Ntime)
#    for t = 1:Ntime, α = 1:Nbase
#        measured.data[α, t] = JonesMatrix(data[1, α, range[t]], 0, 0, data[2, α, range[t]])
#        measured.flags[α, t] = flags[α, range[t]]
#    end
#
#    model = Visibilities(Nbase, Ntime)
#    meta = getmeta(spw, dataset)
#    meta.channels = meta.channels[55:55]
#
#    sources = readsources(joinpath(Common.workspace, "source-lists", "getdata-sources.json"))[1:2]
#    if dataset == "rainy"
#        # use measured flux for Cas
#        if spw == 4
#            cyg = 28371.8
#            cas = 30624.7
#        elseif spw == 6
#            cyg = 25887.7
#            cas = 28490.6
#        elseif spw == 8
#            cyg = 24129.8
#            cas = 25420.0
#        elseif spw == 10
#            cyg = 22547.1
#            cas = 23263.5
#        elseif spw == 12
#            cyg = 20911.2
#            cas = 20799.3
#        elseif spw == 14
#            cyg = 19813.8
#            cas = 19226.2
#        elseif spw == 16
#            cyg = 19051.0
#            cas = 18337.2
#        elseif spw == 18
#            cyg = 18256.9
#            cas = 17133.9
#        end
#        baars_cyg = StokesVector(TTCal.get_total_flux(sources[1], meta.channels[1])).I
#        baars_cas = StokesVector(TTCal.get_total_flux(sources[2], meta.channels[1])).I
#        scaleflux!(sources[2], (baars_cyg/cyg) * (cas/baars_cas), 0)
#    end
#    if dataset == "rainy"
#        # use measured beam models
#        if spw == 4
#            coeff = [0.538556463745644
#                     -0.46866163121041965
#                     -0.02903632892950315
#                     -0.008211454946665317
#                     -0.02455123886166189
#                     0.010200717351278811
#                     -0.002733004888223435
#                     0.012097962867146641
#                     -0.010822907679258361]
#        elseif spw == 6
#            coeff = [0.5683128514113496
#                     -0.46414332768707584
#                     -0.049794949824191796
#                     0.01956938394264056
#                     -0.028882062170310224
#                     -0.014311075332807512
#                     -0.011543291444545006
#                     0.00665053503527859
#                     -0.009348228819604933]
#        elseif spw == 8
#            coeff = [0.5607524388115745
#                     -0.45968937134966986
#                     -0.04003477671659007
#                     0.0054334058818740925
#                     -0.029365565655034547
#                     -0.00022684333835518863
#                     -0.009772599099687997
#                     0.007190059779729073
#                     -0.01494324389373882]
#        elseif spw == 10
#            coeff = [0.5648697259136155
#                     -0.45908927749490525
#                     -0.03752995939112614
#                     0.0033934821314708244
#                     -0.030484384773088687
#                     0.012225490320833442
#                     -0.016913428790483902
#                     -0.004324269518531433
#                     -0.013275940628521119]
#        elseif spw == 12
#            coeff = [0.5647179136016398
#                     -0.46118768245292385
#                     -0.029017043660228167
#                     -0.009711516291480747
#                     -0.028346498468994164
#                     0.03494942227085211
#                     -0.025235050863329916
#                     -0.011928112667488994
#                     -0.013449331024941094]
#        elseif spw == 14
#            coeff = [0.5634780036856724
#                     -0.45239381573418425
#                     -0.020553945369180798
#                     -0.0038610634839508044
#                     -0.03766765187104518
#                     0.034987669943576286
#                     -0.03298552592171939
#                     -0.017952720352740013
#                     -0.014260163639469253]
#        elseif spw == 16
#            coeff = [0.554736976435005
#                     -0.4446983513779896
#                     -0.019835734224238583
#                     -0.008902626634517375
#                     -0.04089653832893597
#                     0.02106671073637622
#                     -0.02049607316869055
#                     0.002052177725883946
#                     -0.021225318022073877]
#        elseif spw == 18
#            coeff = [0.5494343726261235
#                     -0.4422544222256613
#                     -0.010377387323544141
#                     -0.020193950880921727
#                     -0.03933368453654855
#                     0.03569618734453113
#                     -0.020645215922528007
#                     -0.0007547051500611155
#                     -0.02480903125367872]
#        end
#        beam = ZernikeBeam(coeff)
#    else
#        beam = SineBeam()
#    end
#
#    # We need to generate the model visibilities one-by-one because TTCal will only do one
#    # integration at a time. At this point we need to make sure TTCal knows that we only want a
#    # single channel.
#
#    for t = 1:Ntime
#        meta.time = Epoch(epoch"UTC", times[range[t]]*seconds)
#        meta.phase_center = Direction(dir"AZEL", 0degrees, 90degrees)
#        _model = genvis(meta, beam, sources)
#        model.data[:, t] = _model.data[:, 1]
#    end
#
#    # Now that we have all of the model visibilities, we can pretend that each integration is a
#    # different frequency channel, but the frequency of each of these channels is the same.
#
#    meta.channels = fill(meta.channels[1], Ntime)
#    TTCal.flag_short_baselines!(measured, meta, 15.0)
#    calibration = GainCalibration(Nant, 1)
#    TTCal.solve_allchannels!(calibration, measured, model, meta, 100, 1e-3)
#
#    calibration
#end

end

