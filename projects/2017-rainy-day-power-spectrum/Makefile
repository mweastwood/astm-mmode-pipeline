.PHONY: all
all: dirty-map power-spectrum

.PHONY: raw
raw: .pipeline/000-raw-data

.PHONY: calibrate
calibrate: .pipeline/002-calibrated-data

.PHONY: dirty-map
dirty-map: .pipeline/032-dirty-map

.PHONY: transfer-matrix
transfer-matrix: .pipeline/100-transfer-matrix

.PHONY: fisher-matrix
fisher-matrix: .pipeline/121-fisher-matrix

.PHONY: power-spectrum
power-spectrum: \
	.pipeline/123a-quadratic-estimator \
	.pipeline/123b-quadratic-estimator \
	.pipeline/123c-quadratic-estimator

#.PHONY: signal-injection
#signal-injection: .pipeline/123-injected-quadratic-estimator

BIN=../../bin
LIB=../../lib
JULIA=julia-0.6 --color=yes
LAUNCH=$(JULIA) $(BIN)/launch.jl

define launch
	$(LAUNCH) $(filter-out .pipeline/%,$^)
	touch $@
endef

define launch-remote
	$(LAUNCH) --remote-workers $(1) $(filter-out .pipeline/%,$^)
	touch $@
endef

# Some of these targets require significant resources on a machine and so we cannot reliably run
# anything in parallel. Currently there is no way to mark specific targets as ".NOTPARALLEL", so for
# now we have to mark the entire Makefile.
.NOTPARALLEL:

####################################################################################################
# DATA REDUCTION

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

####################################################################################################
# M-MODE ANALYSIS BASICS AND IMAGING

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

.pipeline/101-averaged-m-modes: .pipeline/031-m-modes \
		$(LIB)/101-average-channels.jl project.yml 101-average-channels-m-modes.yml
	$(LAUNCH) --remote-workers 1 $(filter-out .pipeline/%,$^)

.pipeline/101-averaged-transfer-matrix: .pipeline/100-transfer-matrix \
		$(LIB)/101-average-channels.jl project.yml 101-average-channels-transfer-matrix.yml
	$(LAUNCH) --remote-workers 1 $(filter-out .pipeline/%,$^)

.pipeline/102-noise-covariance-matrix: .pipeline/000-raw-data .pipeline/100-transfer-matrix \
		.pipeline/101-averaged-transfer-matrix \
		$(LIB)/102-noise-covariance-matrix.jl project.yml 102-noise-covariance-matrix.yml
	$(LAUNCH) --remote-workers 1 $(filter-out .pipeline/%,$^)

.pipeline/103-compressed-m-modes: .pipeline/101-averaged-m-modes \
		.pipeline/101-averaged-transfer-matrix .pipeline/102-noise-covariance-matrix \
		$(LIB)/103-full-rank-compress.jl project.yml 103-full-rank-compress.yml
	$(LAUNCH) --remote-workers 1 $(filter-out .pipeline/%,$^)

####################################################################################################
# FOREGROUND FILTERING AND QUADRATIC ESTIMATOR

.pipeline/110-foreground-covariance-matrix: \
		$(LIB)/110-foreground-covariance-matrix.jl project.yml 110-foreground-covariance-matrix.yml \
		.pipeline/101-averaged-m-modes
	$(launch)

.pipeline/111-signal-covariance-matrix: \
		$(LIB)/111-signal-covariance-matrix.jl project.yml 111-signal-covariance-matrix.yml \
		.pipeline/101-averaged-m-modes
	$(launch)

.pipeline/112%-foreground-filter: \
		$(LIB)/112-foreground-filter.jl project.yml 112%-foreground-filter.yml \
		.pipeline/103-compressed-m-modes \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/120-basis-covariance-matrices: \
		$(LIB)/120-basis-covariance-matrices.jl project.yml 120-basis-covariance-matrices.yml \
		.pipeline/101-averaged-m-modes
	$(call launch-remote,2)

.pipeline/121%-fisher-matrix: \
		$(LIB)/121-fisher-matrix.jl project.yml 121%-fisher-matrix.yml \
	    .pipeline/112%-foreground-filter \
		.pipeline/120-basis-covariance-matrices
	$(call launch-remote,2)

.pipeline/122%-noise-bias: \
		$(LIB)/122-noise-bias.jl project.yml 122%-noise-bias.yml \
		.pipeline/112%-foreground-filter \
		.pipeline/120-basis-covariance-matrices
	$(call launch-remote,2)

.pipeline/123%-quadratic-estimator: \
		$(LIB)/123-quadratic-estimator.jl project.yml 123%-quadratic-estimator.yml \
		.pipeline/112%-foreground-filter \
		.pipeline/120-basis-covariance-matrices \
		.pipeline/121%-fisher-matrix \
		.pipeline/122%-noise-bias
	$(launch)

#.pipeline/124-injected-m-modes: \
#		$(LIB)/124-signal-injection.jl project.yml 124-signal-injection.yml \
#		.pipeline/103-compressed-m-modes \
#		.pipeline/112-foreground-filter
#	$(launch)
#
#.pipeline/123-injected-quadratic-estimator: \
#		$(LIB)/123-quadratic-estimator.jl project.yml 123-injected-quadratic-estimator.yml \
#		.pipeline/112-foreground-filter \
#		.pipeline/121-fisher-matrix \
#		.pipeline/122-noise-bias \
#		.pipeline/120-basis-covariance-matrices \
#		.pipeline/124-injected-m-modes
#	$(launch)

