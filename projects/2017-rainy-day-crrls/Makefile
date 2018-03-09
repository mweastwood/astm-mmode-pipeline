.PHONY: all raw fold m-modes transfer-matrix

BIN=../../bin
LIB=../../lib
LAUNCH=$(BIN)/launch.jl

all: dirty-map
raw: .pipeline/raw-visibilities
fold: .pipeline/folded-visibilities
m-modes: .pipeline/m-modes
dirty-map: .pipeline/dirty-map
transfer-matrix: .pipeline/transfer-matrix

.pipeline/raw-visibilities: $(LIB)/000-getdata.jl project.yml dada2ms.yml raw-data.yml
	$(LAUNCH) --remote-workers 2 $^

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
	$(LAUNCH) --remote-workers 1 $(filter-out $<,$^)

.pipeline/m-modes: .pipeline/folded-visibilities \
		$(LIB)/031-getmmodes.jl project.yml m-modes.yml
	$(LAUNCH) --remote-workers 1 $(filter-out $<,$^)

.pipeline/dirty-map: .pipeline/m-modes .pipeline/transfer-matrix \
		$(LIB)/032-tikhonov.jl project.yml tikhonov.yml
	$(LAUNCH) --remote-workers 1 $(filter-out .pipeline/%,$^)

.pipeline/transfer-matrix: .pipeline/raw-data \
		$(LIB)/100-transfer-matrix.jl project.yml transfer-matrix.yml
	$(LAUNCH) --remote-workers 4 $(filter-out $<,$^)

