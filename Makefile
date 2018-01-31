
SPW  = 17
NAME = rainy

DIRECTORY = workspace/spw$(SPW)/$(NAME)
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

ROUTINE_GETDATA   = $(wildcard pipeline/00-getdata/*)
ROUTINE_TRANSPOSE = $(wildcard pipeline/01-transpose/*)
ROUTINE_FLAG1     = $(wildcard pipeline/02-flag/*)
ROUTINE_CALIBRATE = $(wildcard pipeline/03-calibrate/*)
ROUTINE_FLAG2     = $(wildcard pipeline/04-flag/*)

ROUTINE_FITRFI1   = $(wildcard pipeline/10-fitrfi-stationary/*)
ROUTINE_SUBRFI1   = $(wildcard pipeline/11-subrfi-stationary/*)
ROUTINE_FITRFI2   = $(wildcard pipeline/12-fitrfi-impulsive/*)
ROUTINE_SUBRFI2   = $(wildcard pipeline/13-subrfi-impulsive/*)
ROUTINE_PEEL      = $(wildcard pipeline/20-peel/*)
ROUTINE_FOLD      = $(wildcard pipeline/30-fold/*)
ROUTINE_GETMMODES = $(wildcard pipeline/31-getmmodes/*)
ROUTINE_TIKHONOV  = $(wildcard pipeline/32-tikhonov/*)

.PHONY: all peel

all:       $(DIRTYALM)
subrfi:    $(SUBRFI2)
fitrfi:    $(FITRFI2)
peel:      $(PEELED)
calibrate: $(CALIBRATED)
raw:       $(RAW)
test:      $(FLAGGED_CALIBRATED)

$(RAW): $(ROUTINE_GETDATA)
	cd pipeline/00-getdata; ./go.jl $(SPW) $(NAME)

$(FLAGGED): $(ROUTINE_FLAG1) $(RAW)
	cd pipeline/02-flag; ./go.jl $(SPW) $(NAME)

$(CALIBRATED): $(ROUTINE_CALIBRATE) $(FLAGGED)
	cd pipeline/03-calibrate; ./go.jl $(SPW) $(NAME)

$(FLAGGED_CALIBRATED): $(ROUTINE_FLAG2) $(CALIBRATED)
	cd pipeline/04-flag; ./go.jl $(SPW) $(NAME)

$(FITRFI1): $(ROUTINE_FITRFI1) $(FLAGGED_CALIBRATED)
	cd pipeline/10-fitrfi-stationary; ./go.jl $(SPW) $(NAME)

$(SUBRFI1): $(ROUTINE_SUBRFI1) $(FLAGGED_CALIBRATED) $(FITRFI1)
	cd pipeline/11-subrfi-stationary; ./go.jl $(SPW) $(NAME)

$(FITRFI2): $(ROUTINE_FITRFI2) $(SUBRFI1)
	cd pipeline/12-fitrfi-impulsive; ./go.jl $(SPW) $(NAME)

$(SUBRFI2): $(ROUTINE_SUBRFI2) $(SUBRFI1) $(FITRFI2)
	cd pipeline/13-subrfi-impulsive; ./go.jl $(SPW) $(NAME)

$(PEELED): $(ROUTINE_PEEL) $(SUBRFI2)
	cd pipeline/20-peel; ./go.jl $(SPW) $(NAME)

$(FOLDED): $(ROUTINE_FOLD) $(PEELED)
	cd pipeline/30-fold; ./go.jl $(SPW) $(NAME)

$(MMODES): $(ROUTINE_GETMMODES) $(FOLDED)
	cd pipeline/31-getmmodes; ./go.jl $(SPW) $(NAME)

$(DIRTYALM): $(ROUTINE_TIKHONOV) $(MMODES)
	cd pipeline/32-tikhonov; ./go.jl $(SPW) $(NAME)

