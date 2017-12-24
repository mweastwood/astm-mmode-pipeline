
SPW  = 18
NAME = rainy

DIRECTORY = workspace/spw$(SPW)/$(NAME)
RAW        = $(DIRECTORY)/raw-visibilities.jld2
TRANSPOSED = $(DIRECTORY)/transposed-visibilities.jld2
FLAGGED    = $(DIRECTORY)/flagged-visibilities.jld2
CALIBRATED = $(DIRECTORY)/calibrated-visibilities.jld2
SMEARED    = $(DIRECTORY)/smeared-visibilities.jld2
RFIREMOVED = $(DIRECTORY)/rfiremoved-visibilities.jld2
PEELED     = $(DIRECTORY)/peeled-visibilities.jld2

#FOLDED     = $(DIRECTORY)/foled-visibilities.jld2
#MMODES     = $(DIRECTORY)/m-modes/METADATA.jld2
#DIRTYALM   = $(DIRECTORY)/dirty-alm.jld2

.PHONY: all test

all: $(DIRTYALM)

test: $(PEELED)

GETDATA = $(wildcard pipeline/00-getdata/*)
$(RAW): $(GETDATA)
	cd pipeline/00-getdata; ./go.jl $(SPW) $(NAME)

TRANSPOSE = $(wildcard pipeline/01-transpose/*)
$(TRANSPOSED): $(TRANSPOSE) $(RAW)
	cd pipeline/01-transpose; ./go.jl $(SPW) $(NAME)

FLAG = $(wildcard pipeline/02-flag/*)
$(FLAGGED): $(FLAG) $(TRANSPOSED) $(RAW)
	cd pipeline/02-flag; ./go.jl $(SPW) $(NAME)

CALIBRATE = $(wildcard pipeline/03-calibrate/*)
$(CALIBRATED): $(CALIBRATE) $(FLAGGED)
	cd pipeline/03-calibrate; ./go.jl $(SPW) $(NAME)

SMEAR = $(wildcard pipeline/10-smear/*)
$(SMEARED): $(SMEAR) $(CALIBRATED)
	cd pipeline/10-smear; ./go.jl $(SPW) $(NAME)

SUBRFI = $(wildcard pipeline/11-subrfi/*)
$(RFIREMOVED): $(SUBRFI) $(CALIBRATED) $(SMEARED)
	cd pipeline/11-subrfi; ./go.jl $(SPW) $(NAME)

PEEL = $(wildcard pipeline/20-peel/*)
$(PEELED): $(PEEL) $(RFIREMOVED)
	cd pipeline/20-peel; ./go.jl $(SPW) $(NAME)

#FOLD = $(wildcard pipeline/20-fold/*)
#$(FOLDED): $(FOLD) $(TRANSPOSED)
#	cd pipeline/20-fold; ./go.jl $(SPW) $(NAME)
#
#GETMMODES = $(wildcard pipeline/21-getmmodes/*)
#$(MMODES): $(GETMMODES) $(FOLDED)
#	cd pipeline/21-getmmodes; ./go.jl $(SPW) $(NAME)
#
#TIKHONOV = $(wildcard pipeline/22-tikhonov/*)
#$(DIRTYALM): $(TIKHONOV) $(MMODES)
#	cd pipeline/22-tikhonov; ./go.jl $(SPW) $(NAME)

