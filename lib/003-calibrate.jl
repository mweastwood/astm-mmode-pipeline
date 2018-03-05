module Driver

using CasaCore.Measures
using JLD2
using ProgressMeter
using TTCal
using Unitful
using YAML

include("Project.jl")
include("Datasets.jl")
include("WSClean.jl")

struct Config
    input  :: String
    output :: String
    skymodel :: String
    test_image :: String
    integrations :: Vector{Int}
    maxiter   :: Int
    tolerance :: Float64
    minuvw    :: Float64
    delete_input :: Bool
end

function load(file)
    dict = YAML.load(open(file))
    if dict["integrations"] isa String
        string = dict["integrations"]
        split_string = split(string, ":")
        start = parse(Int, split_string[1])
        stop  = parse(Int, split_string[2])
        integrations = start:stop
    else
        integrations = dict["integrations"]
    end
    Config(dict["input"], dict["output"],
           joinpath(dirname(file), dict["sky-model"]), dict["test-image"],
           integrations, dict["maxiter"], dict["tolerance"], dict["minuvw"],
           dict["delete-input"])
end

function go(project_file, wsclean_file, config_file)
    project = Project.load(project_file)
    wsclean = WSClean.load(wsclean_file)
    config  = load(config_file)
    calibrate(project, wsclean, config)
    if config.delete_input
        rm(joinpath(Project.workspace(project), config.input*".jld2"))
    end
    Project.touch(project, config.output)
end

function calibrate(project, wsclean, config)
    dataset, calibration = solve_for_the_calibration(project, config)
    WSClean.run(wsclean, dataset, joinpath(Project.workspace(project), config.test_image))
    apply_the_calibration(project, config, calibration)
end

function solve_for_the_calibration(project, config)
    sky = readsky(config.skymodel)
    measured = read_raw_visibilities(project, config)
    beam = getbeam(measured.metadata)
    model = genvis(measured.metadata, beam, sky, polarization=TTCal.Dual)
    calibration = TTCal.calibrate(measured, model, maxiter=config.maxiter,
                                  tolerance=config.tolerance, minuvw=config.minuvw,
                                  collapse_time=true)
    applycal!(measured, calibration)
    measured, calibration
end

####################################################################################################

function read_raw_visibilities(project, config)
    local dataset
    jldopen(joinpath(Project.workspace(project), config.input*".jld2"), "r") do file
        metadata = file["metadata"]
        TTCal.slice!(metadata, config.integrations, axis=:time)
        dataset = TTCal.Dataset(metadata, polarization=TTCal.Dual)
        prg = Progress(length(config.integrations))
        for (i, j) in enumerate(config.integrations)
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
            if J.xx != 0 && J.yy != 0
                visibilities[antenna1, antenna2] = J
            end
            α += 1
        end
    end
end

o6d(i) = @sprintf("%06d", i)

####################################################################################################

function apply_the_calibration(project, config, calibration)
    jldopen(joinpath(Project.workspace(project), config.input*".jld2"), "r") do input_file
        metadata = input_file["metadata"]

        pool  = CachingPool(workers())
        queue = collect(1:Ntime(metadata))
        lck = ReentrantLock()
        prg = Progress(length(queue))
        increment() = (lock(lck); next!(prg); unlock(lck))

        jldopen(joinpath(Project.workspace(project), config.output*".jld2"), "w") do output_file
            output_file["calibration"] = calibration
            output_file["metadata"] = metadata
            @sync for worker in workers()
                @async while length(queue) > 0
                    index = pop!(queue)
                    raw_data = input_file[o6d(index)]
                    calibrated_data = remotecall_fetch(do_the_work, pool, raw_data, metadata,
                                                       index, calibration)
                    output_file[o6d(index)] = calibrated_data
                    increment()
                end
            end
        end
    end
end

function do_the_work(data, metadata, time, calibration)
    dataset = Datasets.array_to_ttcal(data, metadata, time)
    applycal!(dataset, calibration)
    Datasets.ttcal_to_array(dataset)
end

####################################################################################################

function getbeam(metadata)
    ν = mean(metadata.frequencies)
    νlist = sort(collect(keys(beam_coeff)))
    idx = searchsortedlast(νlist, ν)
    w1 = uconvert(NoUnits, (νlist[idx+1]-ν)/(νlist[idx+1]-νlist[idx]))
    w2 = 1 - w1
    TTCal.ZernikeBeam(w1*beam_coeff[νlist[idx]] + w2*beam_coeff[νlist[idx+1]])
end

beam_coeff = Dict(36.528u"MHz" => [ 0.538556463745644,     -0.46866163121041965,
                                   -0.02903632892950315,   -0.008211454946665317,
                                   -0.02455123886166189,    0.010200717351278811,
                                   -0.002733004888223435,   0.012097962867146641,
                                   -0.010822907679258361],
                  41.760u"MHz" => [ 0.5683128514113496,    -0.46414332768707584,
                                   -0.049794949824191796,   0.01956938394264056,
                                   -0.028882062170310224,  -0.014311075332807512,
                                   -0.011543291444545006,   0.00665053503527859,
                                   -0.009348228819604933],
                  46.992u"MHz" => [ 0.5607524388115745,    -0.45968937134966986,
                                   -0.04003477671659007,    0.0054334058818740925,
                                   -0.029365565655034547,  -0.00022684333835518863,
                                   -0.009772599099687997,   0.007190059779729073,
                                   -0.01494324389373882],
                  52.224u"MHz" => [ 0.5648697259136155,    -0.45908927749490525,
                                   -0.03752995939112614,    0.0033934821314708244,
                                   -0.030484384773088687,   0.012225490320833442,
                                   -0.016913428790483902,  -0.004324269518531433,
                                   -0.013275940628521119],
                  57.456u"MHz" => [ 0.5647179136016398,    -0.46118768245292385,
                                   -0.029017043660228167,  -0.009711516291480747,
                                   -0.028346498468994164,   0.03494942227085211,
                                   -0.025235050863329916,  -0.011928112667488994,
                                   -0.013449331024941094],
                  62.688u"MHz" => [ 0.5634780036856724,    -0.45239381573418425,
                                   -0.020553945369180798,  -0.0038610634839508044,
                                   -0.03766765187104518,    0.034987669943576286,
                                   -0.03298552592171939,   -0.017952720352740013,
                                   -0.014260163639469253],
                  67.920u"MHz" => [ 0.554736976435005,     -0.4446983513779896,
                                   -0.019835734224238583,  -0.008902626634517375,
                                   -0.04089653832893597,    0.02106671073637622,
                                   -0.02049607316869055,    0.002052177725883946,
                                   -0.021225318022073877],
                  73.152u"MHz" => [ 0.5494343726261235,    -0.4422544222256613,
                                   -0.010377387323544141,  -0.020193950880921727,
                                   -0.03933368453654855,    0.03569618734453113,
                                   -0.020645215922528007,  -0.0007547051500611155,
                                   -0.02480903125367872])

####################################################################################################

end

