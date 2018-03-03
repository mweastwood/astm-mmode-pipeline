
SPW  = 17
NAME = rainy

DIRECTORY = workspace/spw$(SPW)/$(NAME)

.PHONY: all
all: power-spectrum

###########
# Imaging #
###########

RAW        = $(DIRECTORY)/raw-visibilities.jld2
TRANSPOSED = $(DIRECTORY)/transposed-raw-visibilities.jld2
FLAGGED    = $(DIRECTORY)/flagged-visibilities.jld2
CALIBRATED = $(DIRECTORY)/calibrated-visibilities.jld2
FLAGGED_CALIBRATED = $(DIRECTORY)/flagged-calibrated-visibilities.jld2

FITRFI1    = $(DIRECTORY)/fitrfi-stationary-coherencies.jld2
SUBRFI1    = $(DIRECTORY)/subrfi-stationary-visibilities.jld2
FITRFI2    = $(DIRECTORY)/fitrfi-impulsive-coherencies.jld2
SUBRFI2    = $(DIRECTORY)/subrfi-impulsive-visibilities.jld2
PEELED     = $(DIRECTORY)/peeled-visibilities.jld2
FOLDED     = $(DIRECTORY)/folded-visibilities.jld2
MMODES     = $(DIRECTORY)/m-modes/METADATA.jld2
DIRTYALM   = $(DIRECTORY)/dirty-alm.jld2

ROUTINE_GETDATA   = $(wildcard pipeline/000-getdata/*)
ROUTINE_TRANSPOSE = $(wildcard pipeline/001-transpose/*)
ROUTINE_FLAG1     = $(wildcard pipeline/002-flag/*)
ROUTINE_CALIBRATE = $(wildcard pipeline/003-calibrate/*)
ROUTINE_FLAG2     = $(wildcard pipeline/004-flag/*)

ROUTINE_FITRFI1   = $(wildcard pipeline/010-fitrfi-stationary/*)
ROUTINE_SUBRFI1   = $(wildcard pipeline/011-subrfi-stationary/*)
ROUTINE_FITRFI2   = $(wildcard pipeline/012-fitrfi-impulsive/*)
ROUTINE_SUBRFI2   = $(wildcard pipeline/013-subrfi-impulsive/*)
ROUTINE_PEEL      = $(wildcard pipeline/020-peel/*)
ROUTINE_FOLD      = $(wildcard pipeline/030-fold/*)
ROUTINE_GETMMODES = $(wildcard pipeline/031-getmmodes/*)
ROUTINE_TIKHONOV  = $(wildcard pipeline/032-tikhonov/*)

.PHONY: subrfi fitrfi peel calibrate raw test
subrfi:    $(SUBRFI2)
fitrfi:    $(FITRFI2)
peel:      $(PEELED)
calibrate: $(CALIBRATED)
raw:       $(RAW)
test:      $(FLAGGED_CALIBRATED)

$(RAW): $(ROUTINE_GETDATA)
	cd pipeline/000-getdata; ./go.jl $(SPW) $(NAME)

$(FLAGGED): $(ROUTINE_FLAG1) $(RAW)
	cd pipeline/002-flag; ./go.jl $(SPW) $(NAME)

$(CALIBRATED): $(ROUTINE_CALIBRATE) $(FLAGGED)
	cd pipeline/003-calibrate; ./go.jl $(SPW) $(NAME)

$(FLAGGED_CALIBRATED): $(ROUTINE_FLAG2) $(CALIBRATED)
	cd pipeline/004-flag; ./go.jl $(SPW) $(NAME)

$(FITRFI1): $(ROUTINE_FITRFI1) $(FLAGGED_CALIBRATED)
	cd pipeline/010-fitrfi-stationary; ./go.jl $(SPW) $(NAME)

$(SUBRFI1): $(ROUTINE_SUBRFI1) $(FLAGGED_CALIBRATED) $(FITRFI1)
	cd pipeline/011-subrfi-stationary; ./go.jl $(SPW) $(NAME)

$(FITRFI2): $(ROUTINE_FITRFI2) $(SUBRFI1)
	cd pipeline/012-fitrfi-impulsive; ./go.jl $(SPW) $(NAME)

$(SUBRFI2): $(ROUTINE_SUBRFI2) $(SUBRFI1) $(FITRFI2)
	cd pipeline/013-subrfi-impulsive; ./go.jl $(SPW) $(NAME)

$(PEELED): $(ROUTINE_PEEL) $(SUBRFI2)
	cd pipeline/020-peel; ./go.jl $(SPW) $(NAME)

$(FOLDED): $(ROUTINE_FOLD) $(PEELED)
	cd pipeline/030-fold; ./go.jl $(SPW) $(NAME)

$(MMODES): $(ROUTINE_GETMMODES) $(FOLDED)
	cd pipeline/031-getmmodes; ./go.jl $(SPW) $(NAME)

$(DIRTYALM): $(ROUTINE_TIKHONOV) $(MMODES)
	cd pipeline/032-tikhonov; ./go.jl $(SPW) $(NAME)

##################
# Power Spectrum #
##################

AVERAGED_TRANSFER_MATRIX     = $(DIRECTORY)/transfer-matrix-averaged/METADATA.jld2
NOISE_COVARIANCE_MATRIX      = $(DIRECTORY)/covariance-matrix-noise/METADATA.jld2
COMPRESSED_TRANSFER_MATRIX   = $(DIRECTORY)/transfer-matrix-compressed/METADATA.jld2
FOREGROUND_COVARIANCE_MATRIX = $(DIRECTORY)/covariance-matrix-fiducial-foregrounds/METADATA.jld2
SIGNAL_COVARIANCE_MATRIX     = $(DIRECTORY)/covariance-matrix-fiducial-signal/METADATA.jld2
FOREGROUND_FILTERED          = $(DIRECTORY)/transfer-matrix-final/METADATA.jld2
BASIS_COVARIANCE_MATRICES    = $(DIRECTORY)/basis-covariance-matrices/FIDUCIAL.jld2
FISHER_MATRIX                = $(DIRECTORY)/fisher-matrix.jld2
QUADRATIC_ESTIMATOR          = $(DIRECTORY)/quadratic-estimator.jld2

ROUTINE_AVERAGE_TRANSFER_MATRIX      = $(wildcard pipeline/101-average-transfer-matrix/*)
ROUTINE_NOISE_COVARIANCE_MATRIX      = $(wildcard pipeline/102-noise-covariance-matrix/*)
ROUTINE_COMPRESS_TRANSFER_MATRIX     = $(wildcard pipeline/103-compress-transfer-matrix/*)
ROUTINE_FOREGROUND_COVARIANCE_MATRIX = $(wildcard pipeline/200-foreground-covariance-matrix/*)
ROUTINE_SIGNAL_COVARIANCE_MATRIX     = $(wildcard pipeline/201-signal-covariance-matrix/*)
ROUTINE_FOREGROUND_FILTER            = $(wildcard pipeline/202-foreground-filter/*)
ROUTINE_BASIS_COVARIANCE_MATRICES    = $(wildcard pipeline/300-basis-covariance-matrices/*)
ROUTINE_FISHER_MATRIX                = $(wildcard pipeline/301-fisher-matrix/*)
ROUTINE_QUADRATIC_ESTIMATOR          = $(wildcard pipeline/302-quadratic-estimator/*)

.PHONY: ps power-spectrum foreground-filtered fisher-matrix quadratic-estimator
ps: power-spectrum
power-spectrum: quadratic-estimator
foreground-filtered: $(FOREGROUND_FILTERED)
fisher-matrix: $(FISHER_MATRIX)
quadratic-estimator: $(QUADRATIC_ESTIMATOR)

$(AVERAGED_TRANSFER_MATRIX): $(ROUTINE_AVERAGE_TRANSFER_MATRIX)
	cd pipeline/101-average-transfer-matrix; ./go.jl $(SPW) $(NAME)

$(NOISE_COVARIANCE_MATRIX): $(ROUTINE_NOISE_COVARIANCE_MATRIX) $(AVERAGED_TRANSFER_MATRIX)
	cd pipeline/102-noise-covariance-matrix; ./go.jl $(SPW) $(NAME)

$(COMPRESSED_TRANSFER_MATRIX): $(ROUTINE_COMPRESS_TRANSFER_MATRIX) $(NOISE_COVARIANCE_MATRIX)
	cd pipeline/103-compress-transfer-matrix; ./go.jl $(SPW) $(NAME)

$(FOREGROUND_COVARIANCE_MATRIX): $(ROUTINE_FOREGROUND_COVARIANCE_MATRIX) $(AVERAGED_TRANSFER_MATRIX)
	cd pipeline/200-foreground-covariance-matrix; ./go.jl $(SPW) $(NAME)

$(SIGNAL_COVARIANCE_MATRIX): $(ROUTINE_SIGNAL_COVARIANCE_MATRIX) $(AVERAGED_TRANSFER_MATRIX)
	cd pipeline/201-signal-covariance-matrix; ./go.jl $(SPW) $(NAME)

$(FOREGROUND_FILTERED): $(ROUTINE_FOREGROUND_FILTER) $(COMPRESSED_TRANSFER_MATRIX) \
					    $(FOREGROUND_COVARIANCE_MATRIX) $(SIGNAL_COVARIANCE_MATRIX)
	cd pipeline/202-foreground-filter; ./go.jl $(SPW) $(NAME)

$(BASIS_COVARIANCE_MATRICES): $(ROUTINE_BASIS_COVARIANCE_MATRICES) $(AVERAGED_TRANSFER_MATRIX)
	cd pipeline/300-basis-covariance-matrices; ./go.jl $(SPW) $(NAME)

$(FISHER_MATRIX): $(ROUTINE_FISHER_MATRIX) $(BASIS_COVARIANCE_MATRICES) $(FOREGROUND_FILTERED)
	cd pipeline/301-fisher-matrix; ./go.jl $(SPW) $(NAME)

$(QUADRATIC_ESTIMATOR): $(ROUTINE_QUADRATIC_ESTIMATOR) $(FISHER_MATRIX)
	cd pipeline/302-quadratic-estimator; ./go.jl $(SPW) $(NAME)

