
SPW  = 18
NAME = rainy

DIRECTORY = workspace/spw$(SPW)
RAW        = $(DIRECTORY)/raw-visibilities.jld2
CALIBRATED = $(DIRECTORY)/calibrated-visibilities.jld2
SMEARED    = $(DIRECTORY)/smeared-visibilities.jld2
PEELED     = $(DIRECTORY)/peeled-visibilities.jld2
TRANSPOSED = $(DIRECTORY)/transposed-visibilities.jld2
FOLDED     = $(DIRECTORY)/foled-visibilities.jld2
MMODES     = $(wildcard $(DIRECTORY)/m-modes/*)

.PHONY: test

test: $(SMEARED)

$(RAW):
	cd pipeline/00-getdata; ./go.jl $(SPW) $(NAME)

$(CALIBRATED): $(RAW)
	cd pipeline/01-calibrate; ./go.jl $(SPW) $(NAME)

$(SMEARED): $(CALIBRATED)
	cd pipeline/04-smear; ./go.jl $(SPW) $(NAME)

#$(PEELED): $(CALIBRATED)
#	cd pipeline/02-peel; ./go.jl $(SPW) $(NAME)
#
#$(TRANSPOSED): $(PEELED)
#	cd pipeline/10-transpose; ./go.jl $(SPW) $(NAME)
#
#$(FOLDED): $(TRANSPOSED)
#	cd pipeline/20-fold; ./go.jl $(SPW) $(NAME)

