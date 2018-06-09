module Driver

using CasaCore.Measures
using JLD2
using ProgressMeter
using TTCal
using BPJSpec
using Unitful
using YAML

include("Project.jl")
include("CreateMeasurementSet.jl")
include("WSClean.jl")
include("TTCalDatasets.jl")
using .TTCalDatasets

struct Config
    input        :: String
    output       :: String
    output_calibration :: String
    metadata     :: String
    skymodel     :: String
    test_image   :: String
    integrations :: Vector{Int}
    maxiter      :: Int
    tolerance    :: Float64
    minuvw       :: Float64
    refant       :: Int # the reference antenna (we have just let the overall phase float until now)
    order        :: Int # order of the polynomial fit to the bandpass amplitude
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
    Config(dict["input"],
           get(dict, "output", ""),
           get(dict, "output-calibration", ""),
           dict["metadata"],
           joinpath(dirname(file), dict["sky-model"]),
           dict["test-image"],
           integrations,
           dict["maxiter"],
           dict["tolerance"],
           dict["minuvw"],
           dict["refant"],
           dict["order"],
           dict["delete-input"])
end

function go(project_file, wsclean_file, config_file)
    project = Project.load(project_file)
    wsclean = WSClean.load(wsclean_file)
    config  = load(config_file)
    calibrate(project, wsclean, config)
    if config.delete_input
        Project.rm(project, config.input)
    end
end

function calibrate(project, wsclean, config)
    path = Project.workspace(project)
    dataset, calibration, bandpass_coeff = solve_for_the_calibration(project, config)
    ms = CreateMeasurementSet.create(dataset, joinpath(path, config.test_image*".ms"))
    WSClean.run(wsclean, ms, joinpath(path, config.test_image))
    if config.output_calibration != ""
        Project.save(project, config.output_calibration, "calibration", calibration,
                     "bandpass-coefficients", bandpass_coeff)
    end
    if config.output != ""
        apply_the_calibration(project, config, calibration)
    end
end

function solve_for_the_calibration(project, config)
    sky = readsky(config.skymodel)
    measured = read_raw_visibilities(project, config)
    beam = getbeam(measured.metadata)
    model = genvis(measured.metadata, beam, sky, polarization=TTCal.Dual)
    calibration = TTCal.calibrate(measured, model, maxiter=config.maxiter,
                                  tolerance=config.tolerance, minuvw=config.minuvw,
                                  collapse_time=true)
    coeff = smooth!(calibration, measured.metadata, config)
    applycal!(measured, calibration)
    measured, calibration, coeff
end

####################################################################################################

function read_raw_visibilities(project, config)
    path = Project.workspace(project)
    input = BPJSpec.load(joinpath(path, config.input))
    metadata = Project.load(project, config.metadata, "metadata")
    TTCal.slice!(metadata, config.integrations, axis=:time)
    dataset = TTCal.Dataset(metadata, polarization=TTCal.Dual)
    prg = Progress(length(config.integrations))
    for (i, j) in enumerate(config.integrations)
        pack!(dataset, input[j], i)
        next!(prg)
    end
    dataset
end

function pack!(dataset, array, index)
    T = size(array, 1) == 2 ? TTCal.Dual : TTCal.Full
    for frequency = 1:Nfreq(dataset)
        visibilities = dataset[frequency, index]
        α = 1
        for antenna1 = 1:Nant(dataset), antenna2 = antenna1:Nant(dataset)
            J = pack_jones_matrix(array, frequency, α, T)
            if J.xx != 0 && J.yy != 0
                visibilities[antenna1, antenna2] = J
            end
            α += 1
        end
    end
end

####################################################################################################

function smooth!(calibration, metadata, config)
    ν = metadata.frequencies
    coeff  = zeros(config.order + 4, 2, Nant(metadata))
    input  = cal_to_array(calibration, metadata, config.refant)
    output = zeros(Complex128, Nfreq(metadata), 2, Nant(metadata))
    for ant = 1:Nant(metadata)
        coeff[:, 1, ant], output[:, 1, ant] = fit_bandpass(ν, @view(input[:, 1, ant]), config) # xx
        coeff[:, 2, ant], output[:, 2, ant] = fit_bandpass(ν, @view(input[:, 2, ant]), config) # yy
    end
    array_to_cal!(calibration, output, metadata)
    coeff
end

function cal_to_array(calibration, metadata, refant)
    # get the data into a format that is a little easier to work with
    output = zeros(Complex128, 2, Nant(metadata), Nfreq(metadata))
    for β = 1:Nfreq(metadata)
        cal = calibration[β, 1]
        for ant = 1:Nant(metadata)
            J = cal[ant]
            output[1, ant, β] = J.xx
            output[2, ant, β] = J.yy
        end
    end
    # fix the phase to the reference antenna
    for β = 1:Nfreq(metadata)
        xx_phase_factor = conj(output[1, refant, β]) / abs(output[1, refant, β])
        yy_phase_factor = conj(output[2, refant, β]) / abs(output[2, refant, β])
        output[1, :, β] .*= xx_phase_factor
        output[2, :, β] .*= yy_phase_factor
    end
    # put frequency on the fast axis
    output = permutedims(output, (3, 1, 2)) # Nfreq × Npol × Nant
end

function array_to_cal!(calibration, array, metadata)
    for β = 1:Nfreq(metadata)
        cal = calibration[β, 1]
        for ant = 1:Nant(metadata)
            J = TTCal.DiagonalJonesMatrix(array[β, 1, ant], array[β, 2, ant])
            cal[ant] = J
        end
    end
end

function fit_bandpass(ν, gains, config)
    amplitude =   abs.(gains)
    phase     = angle.(gains)
    flags = isnan.(amplitude) .| (amplitude .== 0)
    νMHz  = ustrip.(uconvert.(u"MHz", ν))
    amplitude_coeff, amplitude_fit = fit_amplitude(νMHz, amplitude, flags, config.order)
    phase_coeff,     phase_fit     = fit_phase(νMHz, phase, flags)
    complete_coeff = [phase_coeff; amplitude_coeff]
    complete_fit   = amplitude_fit .* cis.(phase_fit)
    complete_coeff, complete_fit
end

function fit_amplitude(νMHz, amplitude, flags, order)
    polyfit(νMHz, amplitude, flags, order)
end

function fit_phase(νMHz, phase, flags)
    #  0 => phase offset relative to the reference antenna
    #  1 => delay term
    # -1 => differential total electron content (ie. relative to the reference antenna)
    # To get the delay in m, multiply by u"c / (2π*MHz)"
    # To get the TEC in TECU, divide by u"q^2 / (4pi*me*ϵ0*c) * (TECU/MHz)"
    polyfit(νMHz, unroll_phase(phase), flags, (0, 1, -1))
end

function polyfit(x, y, flags, order::Int)
    terms = collect(n for n = 0:order)
    polyfit(x, y, flags, terms)
end

function polyfit(x, y, flags, terms::Union{AbstractVector, Tuple})
    A = zeros(eltype(y), length(y), length(terms))
    for (jdx, n) in enumerate(terms)
        for idx = 1:length(y)
            A[idx, jdx] = x[idx]^n
        end
    end
    coeff  = A[.!flags, :] \ y[.!flags]
    values = A * coeff
    coeff, values
end

function unroll_phase(phase)
    unrolled_phase = copy(phase)
    for idx = 1:length(phase)-1
        Δϕ = phase[idx+1] - phase[idx]
        while Δϕ > π
            Δϕ -= 2π
        end
        while Δϕ < -π
            Δϕ += 2π
        end
        unrolled_phase[idx+1] = unrolled_phase[idx] + Δϕ
    end
    unrolled_phase
end

####################################################################################################

function apply_the_calibration(project, config, calibration)
    path = Project.workspace(project)
    Project.set_stripe_count(project, config.output, 1)
    metadata = Project.load(project, config.metadata, "metadata")
    input  = BPJSpec.load(joinpath(path, config.input))
    output = create(BPJSpec.SimpleBlockArray{Complex128, 3},
                    MultipleFiles(joinpath(path, config.output)), Ntime(metadata))

    pool  = CachingPool(workers())
    queue = collect(1:Ntime(metadata))
    lck = ReentrantLock()
    prg = Progress(length(queue))
    increment() = (lock(lck); next!(prg); unlock(lck))

    @sync for worker in workers()
        @async while length(queue) > 0
            index = pop!(queue)
            remotecall_wait(do_the_work, pool, input, output, metadata, calibration, index)
            increment()
        end
    end
end

function do_the_work(input, output, metadata, calibration, index)
    array = input[index]
    T = size(array, 1) == 2 ? TTCal.Dual : TTCal.Full
    dataset = array_to_ttcal(array, metadata, index, T)
    applycal!(dataset, calibration)
    output[index] = ttcal_to_array(dataset)
end

####################################################################################################

function getbeam(metadata)
    ν = mean(metadata.frequencies)
    νlist = sort(collect(keys(beam_coeff)))
    idx = searchsortedlast(νlist, ν)
    if idx == length(νlist)
        return TTCal.ZernikeBeam(beam_coeff[νlist[idx]])
    else
        w1 = uconvert(NoUnits, (νlist[idx+1]-ν)/(νlist[idx+1]-νlist[idx]))
        w2 = 1 - w1
        return TTCal.ZernikeBeam(w1*beam_coeff[νlist[idx]] + w2*beam_coeff[νlist[idx+1]])
    end
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

end

