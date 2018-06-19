module Driver

using BPJSpec
using TTCal
using ProgressMeter
using YAML

include("Project.jl")
include("WSClean.jl")
include("CreateMeasurementSet.jl")
include("TTCalDatasets.jl"); using .TTCalDatasets
include("BeamModels.jl");    using .BeamModels
include("CalibrationFundamentals.jl"); using .CalibrationFundamentals

struct Config
    input       :: String
    metadata    :: String
    calibration :: String
    output      :: String
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["input"],
           dict["metadata"],
           dict["calibration"],
           dict["output"])
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    calibration = Project.load(project, config.calibration, "calibration")
    apply_the_calibration(project, config, calibration)
end

end

