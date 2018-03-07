.PHONY: all raw mmodes transfer

BIN=../../bin
LIB=../../lib
LAUNCH=$(BIN)/launch.jl

all: mmodes
raw: .pipeline/raw-data
mmodes: .pipeline/m-modes
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

.pipeline/m-modes: .pipeline/folded-visibilities \
		$(LIB)/031-getmmodes.jl project.yml m-modes.yml
	$(LAUNCH) $(filter-out $<,$^)

.pipeline/transfer-matrix: .pipeline/raw-data \
		$(LIB)/100-transfer-matrix.jl project.yml transfer-matrix.yml
	$(LAUNCH) --local-workers 8 $(filter-out $<,$^)

