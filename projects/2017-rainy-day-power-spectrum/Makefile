.PHONY: all raw calibrate transfer-matrix dirty-map
all: dirty-map
raw: .pipeline/000-raw-data
calibrate: .pipeline/002-calibrated-data
transfer-matrix: .pipeline/100-transfer-matrix
dirty-map: .pipeline/032-dirty-map

BIN=../../bin
LIB=../../lib
JULIA=julia-0.6 --color=yes
LAUNCH=$(JULIA) $(BIN)/launch.jl

.pipeline/000-raw-data: $(LIB)/000-getdata.jl project.yml dada2ms.yml 000-getdata.yml
	$(LAUNCH) --remote-workers 2 $^

.pipeline/001-flagged-raw-data: .pipeline/000-raw-data \
		$(LIB)/001-flag.jl project.yml 001-flag-raw.yml
	$(LAUNCH) $(filter-out .pipeline/%,$^)

.pipeline/002-calibrated-data: .pipeline/001-flagged-raw-data \
		$(LIB)/002-calibrate.jl project.yml wsclean.yml 002-calibrate.yml
	$(LAUNCH) --remote-workers 1 $(filter-out .pipeline/%,$^)

.pipeline/001-flagged-calibrated-data: .pipeline/002-calibrated-data \
		$(LIB)/001-flag.jl project.yml 001-flag-calibrated.yml
	$(LAUNCH) $(filter-out .pipeline/%,$^)

.pipeline/030-folded-data: .pipeline/001-flagged-calibrated-data \
		$(LIB)/030-fold.jl project.yml 030-fold.yml
	$(LAUNCH) --remote-workers 1 $(filter-out .pipeline/%,$^)

.pipeline/031-m-modes: .pipeline/030-folded-data .pipeline/100-transfer-matrix \
		$(LIB)/031-getmmodes.jl project.yml 031-getmmodes.yml
	$(LAUNCH) --remote-workers 1 $(filter-out .pipeline/%,$^)

.pipeline/032-dirty-map: .pipeline/031-m-modes .pipeline/100-transfer-matrix \
		$(LIB)/032-tikhonov.jl project.yml 032-tikhonov.yml
	$(LAUNCH) --remote-workers 1 $(filter-out .pipeline/%,$^)

.pipeline/100-transfer-matrix: .pipeline/000-raw-data \
		$(LIB)/100-transfer-matrix.jl project.yml 100-transfer-matrix.yml
	$(LAUNCH) --remote-workers 4 $(filter-out .pipeline/%,$^)

#.pipeline/averaged-m-modes: .pipeline/m-modes .pipeline/transfer-matrix \
#		$(LIB)/101-average-channels.jl project.yml averaged-m-modes.yml
#	$(LAUNCH) --remote-workers 1 $(filter-out .pipeline/%,$^)
#
#.pipeline/flagged-m-modes: .pipeline/averaged-m-modes \
#		$(LIB)/102-propagate-flags.jl project.yml flagged-m-modes.yml
#	$(LAUNCH) --remote-workers 1 $(filter-out .pipeline/%,$^)
#
#.pipeline/noise-covariance-matrix: .pipeline/flagged-m-modes \
#		$(LIB)/103-noise-covariance-matrix.jl project.yml noise-covariance-matrix.yml
#	$(LAUNCH) --remote-workers 1 $(filter-out .pipeline/%,$^)
#
#.pipeline/compressed-m-modes: .pipeline/flagged-m-modes .pipeline/noise-covariance-matrix \
#		$(LIB)/104-full-rank-compress.jl project.yml full-rank-compress.yml
#	$(LAUNCH) --remote-workers 1 $(filter-out .pipeline/%,$^)
#
#.pipeline/foreground-covariance-matrix: .pipeline/averaged-m-modes \
#		$(LIB)/110-foreground-covariance-matrix.jl project.yml foreground-covariance-matrix.yml
#	$(LAUNCH) $(filter-out .pipeline/%,$^)
#
#.pipeline/signal-covariance-matrix: .pipeline/averaged-m-modes \
#		$(LIB)/111-signal-covariance-matrix.jl project.yml signal-covariance-matrix.yml
#	$(LAUNCH) $(filter-out .pipeline/%,$^)
#
#.pipeline/filtered-m-modes: .pipeline/compressed-m-modes \
#		.pipeline/foreground-covariance-matrix .pipeline/signal-covariance-matrix \
#		$(LIB)/112-foreground-filter.jl project.yml foreground-filter.yml
#	$(LAUNCH) --remote-workers 2 $(filter-out .pipeline/%,$^)
#
#.pipeline/basis-covariance-matrices: .pipeline/averaged-m-modes \
#		$(LIB)/120-basis-covariance-matrices.jl project.yml basis-covariance-matrices.yml
#	$(LAUNCH) --remote-workers 2 $(filter-out .pipeline/%,$^)
#
#.pipeline/fisher-matrix: .pipeline/basis-covariance-matrices .pipeline/filtered-m-modes \
#		$(LIB)/121-fisher-matrix.jl project.yml fisher-matrix.yml
#	$(LAUNCH) --remote-workers 2 $(filter-out .pipeline/%,$^)
#
#.pipeline/noise-bias: .pipeline/basis-covariance-matrices .pipeline/filtered-m-modes \
#		$(LIB)/122-noise-bias.jl project.yml noise-bias.yml
#	$(LAUNCH) $(filter-out .pipeline/%,$^)
#
#.pipeline/quadratic-estimator: .pipeline/basis-covariance-matrices .pipeline/filtered-m-modes \
#		.pipeline/fisher-matrix .pipeline/noise-bias \
#		$(LIB)/123-quadratic-estimator.jl project.yml quadratic-estimator.yml
#	$(LAUNCH) $(filter-out .pipeline/%,$^)

