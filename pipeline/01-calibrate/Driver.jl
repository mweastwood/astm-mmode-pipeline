module Driver

using CasaCore.Measures
using JLD2
using ProgressMeter
using TTCal
using Unitful

include("../lib/Common.jl"); using .Common

function calibrate(spw, name)
    beam  = getbeam(spw, name)
    sky   = readsky(joinpath(Common.workspace, "source-lists", "calibration-sky-model.json"))
    range = 1600:1700
    calibration = solve_for_the_calibration(spw, name, beam, sky, range)
    apply_the_calibration(spw, name, calibration)
end

function solve_for_the_calibration(spw, name, beam, sky, range)
    measured = read_raw_visibilities(spw, name, range)
    model    = model_visibilities(measured.metadata, beam, sky)
    Common.flag!(spw, name, measured)
    calibration = TTCal.calibrate(measured, model, collapse_time=true)
    calibration
end

function read_raw_visibilities(spw, name, indices)
    local dataset
    jldopen(joinpath(getdir(spw, name), "raw-visibilities.jld2"), "r") do file
        metadata = file["metadata"]
        TTCal.slice!(metadata, indices, axis=:time)
        dataset = TTCal.Dataset(metadata, polarization=TTCal.Dual)
        prg = Progress(length(indices))
        for (i, j) in enumerate(indices)
            pack!(dataset, file[o6d(j)], i)
            next!(prg)
        end
    end
    dataset
end

function pack!(dataset, array, index)
    for frequency = 1:Nfreq(dataset)
        visibilities = dataset[frequency, index]
        α = 1
        for antenna1 = 1:Nant(dataset), antenna2 = antenna1:Nant(dataset)
            J = TTCal.DiagonalJonesMatrix(array[1, frequency, α], array[2, frequency, α])
            visibilities[antenna1, antenna2] = J
            α += 1
        end
    end
end

function model_visibilities(metadata, beam, sky)
    model = genvis(metadata, beam, sky)

    # at the moment genvis only spits out full polarization visibilities, let's manually convert
    # this to dual polarization
    output = TTCal.Dataset(metadata, polarization=TTCal.Dual)
    for time = 1:Ntime(metadata), frequency = 1:Nfreq(metadata)
        vis1 =  model[frequency, time]
        vis2 = output[frequency, time]
        for ant1 = 1:Nant(metadata), ant2 = ant1:Nant(metadata)
            J1 = vis1[ant1, ant2]
            J2 = TTCal.DiagonalJonesMatrix(J1.xx, J1.yy)
            vis2[ant1, ant2] = J2
        end
    end
    output
end

function apply_the_calibration(spw, name, calibration)
    jldopen(joinpath(getdir(spw, name), "raw-visibilities.jld2"), "r") do input_file
        metadata = input_file["metadata"]

        pool  = CachingPool(workers())
        queue = collect(1:Ntime(metadata))

        lck = ReentrantLock()
        prg = Progress(length(queue))
        increment() = (lock(lck); next!(prg); unlock(lck))

        jldopen(joinpath(getdir(spw, name), "calibrated-visibilities.jld2"), "w") do output_file
            @sync for worker in workers()
                @async while length(queue) > 0
                    index = pop!(queue)
                    raw_data = input_file[o6d(index)]
                    calibrated_data = remotecall_fetch(do_the_work, pool, spw, name, raw_data,
                                                       metadata, index, calibration)
                    output_file[o6d(index)] = calibrated_data
                    increment()
                end
            end
            output_file["calibration"] = calibration
            output_file["metadata"] = metadata
        end
    end
end

function do_the_work(spw, name, data, metadata, time, calibration)
    ttcal = array_to_ttcal(data, metadata, time)
    Common.flag!(spw, name, ttcal)
    applycal!(ttcal, calibration)
    ttcal_to_array(ttcal)
end

function array_to_ttcal(array, metadata, time)
    # this assumes one time slice
    metadata = deepcopy(metadata)
    TTCal.slice!(metadata, time, axis=:time)
    ttcal_dataset = TTCal.Dataset(metadata, polarization=TTCal.Dual)
    for frequency in 1:Nfreq(metadata)
        visibilities = ttcal_dataset[frequency, 1]
        α = 1
        for antenna1 = 1:Nant(metadata), antenna2 = antenna1:Nant(metadata)
            J = TTCal.DiagonalJonesMatrix(array[1, frequency, α], array[2, frequency, α])
            visibilities[antenna1, antenna2] = J
            α += 1
        end
    end
    ttcal_dataset
end

function ttcal_to_array(ttcal_dataset)
    # this assumes one time slice
    data = zeros(Complex128, 2, Nfreq(ttcal_dataset), Nbase(ttcal_dataset))
    for frequency in 1:Nfreq(ttcal_dataset)
        visibilities = ttcal_dataset[frequency, 1]
        α = 1
        for antenna1 = 1:Nant(ttcal_dataset), antenna2 = antenna1:Nant(ttcal_dataset)
            J = visibilities[antenna1, antenna2]
            data[1, frequency, α] = J.xx
            data[2, frequency, α] = J.yy
            α += 1
        end
    end
    data
end

function getbeam(spw, dataset)
    if dataset == "rainy"
        return TTCal.ZernikeBeam(beam_coeff[spw])
    else
        return SineBeam()
    end
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

