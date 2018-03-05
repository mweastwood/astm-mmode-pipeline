.PHONY: all

BIN=../../bin
LIB=../../lib
LAUNCH=$(BIN)/launch.jl

all: .pipeline/calibrated-visibilities

.pipeline/raw-data: $(LIB)/000-getdata.jl project.yml dada2ms.yml raw-data.yml
	$(LAUNCH) --local-workers 8 000-getdata.jl project.yml dada2ms.yml raw-data.yml

.pipeline/flagged-visibilities: $(LIB)/002-flag.jl project.yml raw-flags.yml \
		.pipeline/raw-data
	$(LAUNCH) 002-flag.jl project.yml raw-flags.yml

.pipeline/calibrated-visibilities: $(LIB)/003-calibrate.jl project.yml calibrated-data.yml \
		.pipeline/flagged-visibilities
	$(LAUNCH) --local-workers 8 003-calibrate.jl project.yml calibrated-data.yml

.pipeline/flagged-calibrated-visibilities: $(LIB)/002-flag.jl project.yml raw-flags.yml \
		.pipeline/calibrated-visibilities
	$(LAUNCH) 002-flag.jl project.yml calibrated-flags.yml

