
SPW  = 18
NAME = rainy

DIRECTORY = workspace/spw$(SPW)/$(NAME)
RAW        = $(DIRECTORY)/raw-visibilities.jld2
CALIBRATED = $(DIRECTORY)/calibrated-visibilities.jld2
SMEARED    = $(DIRECTORY)/smeared-visibilities.jld2
RFIREMOVED = $(DIRECTORY)/rfiremoved-visibilities.jld2
PEELED     = $(DIRECTORY)/peeled-visibilities.jld2
TRANSPOSED = $(DIRECTORY)/transposed-visibilities.jld2
FOLDED     = $(DIRECTORY)/foled-visibilities.jld2
MMODES     = $(wildcard $(DIRECTORY)/m-modes/*)

.PHONY: test

all: $(PEELED)

GETDATA = $(wildcard pipeline/00-getdata/*)
$(RAW): $(GETDATA)
	cd pipeline/00-getdata; ./go.jl $(SPW) $(NAME)

CALIBRATE = $(wildcard pipeline/01-calibrate/*)
$(CALIBRATED): $(CALIBATE) $(RAW)
	cd pipeline/01-calibrate; ./go.jl $(SPW) $(NAME)

SMEAR = $(wildcard pipeline/04-smear/*)
$(SMEARED): $(SMEAR) $(CALIBRATED)
	cd pipeline/04-smear; ./go.jl $(SPW) $(NAME)

SUBRFI = $(wildcard pipeline/05-subrfi/*)
$(RFIREMOVED): $(SUBRFI) $(CALIBRATED) $(SMEARED)
	cd pipeline/05-subrfi; ./go.jl $(SPW) $(NAME)

PEEL = $(wildcard pipeline/02-peel/*)
$(PEELED): $(PEEL) $(RFIREMOVED)
	cd pipeline/02-peel; ./go.jl $(SPW) $(NAME)

#$(TRANSPOSED): $(PEELED)
#	cd pipeline/10-transpose; ./go.jl $(SPW) $(NAME)
#
#$(FOLDED): $(TRANSPOSED)
#	cd pipeline/20-fold; ./go.jl $(SPW) $(NAME)

