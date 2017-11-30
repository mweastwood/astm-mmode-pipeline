module Driver

using CasaCore.Measures
using JLD2
using ProgressMeter
using TTCal
using Unitful

include("../lib/Common.jl"); using .Common

function calibrate(spw, dataset)
    path = getdir(spw, dataset)
    local calibration
    jldopen(joinpath(path, "raw-visibilities.jld2"), "r") do file
        baseline_flags = file["baseline-flags"]
        calibration = solve_for_gain_calibration(spw, dataset, file, baseline_flags)
        jldopen(joinpath(path, "calibrated-visibilities.jld2"), "w") do output_file
            apply_the_calibration(calibration, file, output_file)
        end
    end
    #jldopen(joinpath(path, "calibration.jld2"), "w") do file
        #file["calibration"] = calibration
    #end
end

function solve_for_gain_calibration(spw, dataset, file, baseline_flags)
    @time measured = create_dataset_all_time(file, baseline_flags, 1600:1700)
    @time model = model_visibilities(spw, dataset, measured.metadata)
    @time calibration = TTCal.calibrate(measured, model)
    calibration
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
    dataset  = TTCal.Dataset(metadata, polarization=TTCal.Dual)
    for frequency = 1:Nfreq(dataset)
        visibilities = dataset[frequency, 1]
        for ant1 = 1:Nant(dataset), ant2 = ant1:Nant(dataset)
            α = baseline_index(ant1, ant2)
            if !baseline_flags[α]
                J = TTCal.DiagonalJonesMatrix(data[1, frequency, α], data[2, frequency, α])
                visibilities[ant1, ant2] = J
            end
        end
    end
    dataset
end

function output_dataset(output_file, dataset, time)
    data = zeros(Complex128, 2, Nfreq(dataset), Nbase(dataset))
    for frequency = 1:Nfreq(dataset)
        visibilities = dataset[frequency, 1]
        for ant1 = 1:Nant(dataset), ant2 = ant1:Nant(dataset)
            α = baseline_index(ant1, ant2)
            J = visibilities[ant1, ant2]
            data[1, frequency, α] = J.xx
            data[2, frequency, α] = J.yy
        end
    end
    output_file[@sprintf("%06d",          time)] = data
    output_file[@sprintf("%06d-metadata", time)] = dataset.metadata
end

function model_visibilities(spw, dataset, metadata)
    sky  = readsky(joinpath(Common.workspace, "source-lists", "calibration-sky-model.json"))
    if dataset == "rainy"
        # use measured beam models
        beam = TTCal.ZernikeBeam(beam_coeff[spw])
    else
        beam = SineBeam()
    end
    model = genvis(metadata, beam, sky)

    # at the moment genvis only spits out full polarization visibilities, let's manually convert
    # this to dual polarization
    output = TTCal.Dataset(metadata, polarization=TTCal.Dual)
    for frequency = 1:Nfreq(metadata)
        vis1 =  model[frequency, 1]
        vis2 = output[frequency, 1]
        for ant1 = 1:Nant(metadata), ant2 = ant1:Nant(metadata)
            J1 = vis1[ant1, ant2]
            J2 = TTCal.DiagonalJonesMatrix(J1.xx, J1.yy)
            vis2[ant1, ant2] = J2
        end
    end
    output
end

function apply_the_calibration(calibration, input_file, output_file)
    Ntime = input_file["Ntime"]
    baseline_flags = input_file["baseline-flags"]
    for time = 1:Ntime
        dataset = create_dataset_one_time(input_file, baseline_flags, time)
        applycal!(dataset, calibration)
        output_dataset(output_file, dataset, time)
    end
    output_file["Ntime"] = Ntime
    output_file["Nfreq"] = input_file["Nfreq"]
end

beam_coeff = Dict( 4 => [ 0.538556463745644,     -0.46866163121041965,   -0.02903632892950315,
                         -0.008211454946665317,  -0.02455123886166189,    0.010200717351278811,
                         -0.002733004888223435,   0.012097962867146641,  -0.010822907679258361],
                   6 => [ 0.5683128514113496,    -0.46414332768707584,   -0.049794949824191796,
                          0.01956938394264056,   -0.028882062170310224,  -0.014311075332807512,
                         -0.011543291444545006,   0.00665053503527859,   -0.009348228819604933],
                   8 => [ 0.5607524388115745,    -0.45968937134966986,   -0.04003477671659007,
                          0.0054334058818740925, -0.029365565655034547,  -0.00022684333835518863,
                         -0.009772599099687997,   0.007190059779729073,  -0.01494324389373882],
                  10 => [ 0.5648697259136155,    -0.45908927749490525,   -0.03752995939112614,
                          0.0033934821314708244, -0.030484384773088687,   0.012225490320833442,
                         -0.016913428790483902,  -0.004324269518531433,  -0.013275940628521119],
                  12 => [ 0.5647179136016398,    -0.46118768245292385,   -0.029017043660228167,
                         -0.009711516291480747,  -0.028346498468994164,   0.03494942227085211,
                         -0.025235050863329916,  -0.011928112667488994,  -0.013449331024941094],
                  14 => [ 0.5634780036856724,    -0.45239381573418425,   -0.020553945369180798,
                         -0.0038610634839508044, -0.03766765187104518,    0.034987669943576286,
                         -0.03298552592171939,   -0.017952720352740013,  -0.014260163639469253],
                  16 => [ 0.554736976435005,     -0.4446983513779896,    -0.019835734224238583,
                         -0.008902626634517375,  -0.04089653832893597,    0.02106671073637622,
                         -0.02049607316869055,    0.002052177725883946,  -0.021225318022073877],
                  18 => [ 0.5494343726261235,    -0.4422544222256613,    -0.010377387323544141,
                         -0.020193950880921727,  -0.03933368453654855,    0.03569618734453113,
                         -0.020645215922528007,  -0.0007547051500611155, -0.02480903125367872])

end

