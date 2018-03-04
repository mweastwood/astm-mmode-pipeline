.PHONY: all

BIN=../../bin
LIB=../../lib
LAUNCH=$(BIN)/launch.jl

all: .pipeline/raw-flags

.pipeline/raw-data: $(LIB)/000-getdata.jl project.yml dada2ms.yml raw-data.yml
	$(LAUNCH) --local-workers 8 000-getdata.jl project.yml dada2ms.yml raw-data.yml

.pipeline/raw-flags: $(LIB)/002-flag.jl project.yml raw-flags.yml \
		.pipeline/raw-data
	$(LAUNCH) 002-flag.jl project.yml raw-flags.yml

.pipeline/calibrated-data: $(LIB)/003-calibrate.jl project.yml calibrated-data.yml \
		.pipeline/raw-flags
	$(LAUNCH) 003-calibrate.jl project.yml calibrated-data.yml

.pipeline/calibrated-flags: $(LIB)/002-flag project.yml raw-flags.yml \
		.pipeline/calibrated-data
	$(LAUNCH) 002-flag.jl project.yml calibrated-flags.yml

