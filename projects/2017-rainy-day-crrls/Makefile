.PHONY: all raw transfer

BIN=../../bin
LIB=../../lib
LAUNCH=$(BIN)/launch.jl

all: .pipeline/folded-visibilities
raw: .pipeline/raw-data
transfer: .pipeline/transfer-matrix

.pipeline/raw-data: $(LIB)/000-getdata.jl project.yml dada2ms.yml raw-data.yml
	$(LAUNCH) --local-workers 8 $^

.pipeline/flagged-visibilities: .pipeline/raw-data \
		$(LIB)/002-flag.jl project.yml raw-flags.yml
	$(LAUNCH) $(filter-out $<,$^)

.pipeline/calibrated-visibilities: .pipeline/flagged-visibilities \
		$(LIB)/003-calibrate.jl project.yml wsclean.yml calibrated-data.yml
	$(LAUNCH) --local-workers 8 $(filter-out $<,$^)

.pipeline/flagged-calibrated-visibilities: .pipeline/calibrated-visibilities \
		$(LIB)/002-flag.jl project.yml calibrated-flags.yml
	$(LAUNCH) $(filter-out $<,$^)

.pipeline/folded-visibilities: .pipeline/flagged-calibrated-visibilities \
		$(LIB)/030-fold.jl project.yml folded-data.yml
	$(LAUNCH) $(filter-out $<,$^)

.pipeline/transfer-matrix: .pipeline/raw-data \
		$(LIB)/100-transfer-matrix.jl project.yml transfer-matrix.yml
	$(LAUNCH) --local-workers 8 $(filter-out $<,$^)

