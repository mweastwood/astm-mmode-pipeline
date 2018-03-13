.PHONY: all raw calibrate fold m-modes transfer-matrix dirty-map average

BIN=../../bin
LIB=../../lib
JULIA=julia-0.6 --color=yes
LAUNCH=$(JULIA) $(BIN)/launch.jl

all: average
raw: .pipeline/raw-visibilities
flag: .pipeline/flagged-visibilities
calibrate: .pipeline/calibrated-visibilities
fold: .pipeline/folded-visibilities
m-modes: .pipeline/m-modes
transfer-matrix: .pipeline/transfer-matrix
dirty-map: .pipeline/dirty-map

average: .pipeline/averaged-m-modes

.pipeline/raw-visibilities: $(LIB)/000-getdata.jl project.yml dada2ms.yml raw-data.yml
	$(LAUNCH) --remote-workers 2 $^

.pipeline/flagged-visibilities: .pipeline/raw-visibilities \
		$(LIB)/001-flag.jl project.yml raw-flags.yml
	$(LAUNCH) $(filter-out $<,$^)

.pipeline/calibrated-visibilities: .pipeline/flagged-visibilities \
		$(LIB)/002-calibrate.jl project.yml wsclean.yml calibrated-data.yml
	$(LAUNCH) --remote-workers 1 $(filter-out $<,$^)

.pipeline/flagged-calibrated-visibilities: .pipeline/calibrated-visibilities \
		$(LIB)/001-flag.jl project.yml calibrated-flags.yml
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

.pipeline/averaged-m-modes: .pipeline/m-modes .pipeline/transfer-matrix \
		$(LIB)/101-average-channels.jl project.yml averaged-m-modes.yml
	$(LAUNCH) --remote-workers 1 $(filter-out .pipeline/%,$^)

