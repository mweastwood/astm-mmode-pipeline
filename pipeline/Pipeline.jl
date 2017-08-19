module Pipeline

include("Utility/Utility.jl") # interfaces to external utilities like dada2ms and wsclean
include("Common/Common.jl")   # common functionality needed for working with OVRO LWA datasets

include("Calibration/Calibration.jl")
include("MModes/MModes.jl")
include("Cleaning/Cleaning.jl")
include("PostProcessing/PostProcessing.jl")

end

