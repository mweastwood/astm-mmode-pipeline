module Driver

include("Project.jl")
include("TTCalDatasets.jl"); using .TTCalDatasets
include("BeamModels.jl");    using .BeamModels
include("CalibrationFundamentals.jl"); using .CalibrationFundamentals


struct Config
    input        :: String
    output       :: String
    output_calibration :: String
    metadata     :: String
    skymodel     :: String
    additional_model_visibilities :: String
    test_image   :: String
    integrations :: Vector{Int}
    channels_at_a_time :: Int
    maxiter      :: Int
    tolerance    :: Float64
    minuvw       :: Float64
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
    Config(dict["input"],
           dict["output"],
           dict["output-calibration"],
           dict["metadata"],
           joinpath(dirname(file), dict["sky-model"]),
           dict["test-image"],
           integrations,
           get(dict, "channels-at-a-time", 0),
           dict["maxiter"],
           dict["tolerance"],
           dict["minuvw"])
end

function go(project_file, wsclean_file, config_file)
    project = Project.load(project_file)
    wsclean = WSClean.load(wsclean_file)
    config  = load(config_file)
    recalibrate(project, wsclean, config)
end

function recalibrate(project, wsclean, config)
    path = Project.workspace(project)
    calibration = solve_for_the_calibration(project, config)
    #create_test_image(project, wsclean, config, calibration)
    #if config.output_calibration != ""
    #    Project.save(project, config.output_calibration, "calibration", calibration)
    #end
    #if config.output_bandpass != ""
    #    Project.save(project, config.output_bandpass, "bandpass-parameters", bandpass_coeff)
    #end
    #if config.output != ""
    #    apply_the_calibration(project, config, calibration)
    #end
end

function solve_for_the_calibration(project, config)
    println("Solving for the calibration")
    metadata = Project.load(project, config.metadata, "metadata")
    if config.channels_at_a_time > 0
        queue = collect(Iterators.partition(1:Nfreq(metadata), config.channels_at_a_time))
        # We don't know what order the calibration will finish in, so we'll write them all down
        # along with their channel numbers and stitch it back together at the end.
        calibrations = Dict{Int, TTCal.Calibration}() # maps (first channel) => (calibration)
        @sync for worker in workers()
            @async while length(queue) > 0
                channels = shift!(queue)
                my_calibration = remotecall_fetch(solve_for_the_calibration_with_channels, worker,
                                                  project, config, channels)
                calibrations[first(channels)] = my_calibration
            end
        end
        # Stitch it back together
        sorted_keys = sort(collect(keys(calibrations)))
        calibration = calibrations[first(sorted_keys)]
        for key in sorted_keys[2:end]
            TTCal.merge!(calibration, calibrations[key], axis=:frequency)
        end
    else
        # We're taking all the channels at once, and we'll do the calibration on the master process
        calibration = solve_for_the_calibration_with_channels(project, config, 1:Nfreq(metadata))
    end
    calibration
end

function solve_for_the_calibration_with_channels(project, config, channels)
    @time begin
        metadata = Project.load(project, config.metadata, "metadata")
        sky = readsky(config.skymodel)
        beam  = getbeam(metadata)
        measured = read_raw_visibilities(project, config, channels)
        model    = genvis(measured.metadata, beam, sky, polarization=TTCal.Dual)
        calibration = TTCal.calibrate(measured, model, maxiter=config.maxiter,
                                      tolerance=config.tolerance, minuvw=config.minuvw,
                                      collapse_time=true, quiet=true)
    end
    calibration
end




end

