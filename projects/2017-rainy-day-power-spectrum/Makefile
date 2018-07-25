.PHONY: all
all: dirty-maps power-spectrum

.PHONY: raw
raw: .pipeline/000-raw-data

.PHONY: calibrate
calibrate: .pipeline/003-calibrated-data

.PHONY: fitrfi
fitrfi: .pipeline/010-fitrfi

.PHONY: subrfi
subrfi: .pipeline/011-subrfi

.PHONY: peel
peel: .pipeline/020-peeled-data

.PHONY: recalibrate
recalibrate: \
	.pipeline/040-recalibrate \
	.pipeline/041-recalibrate-apply

.PHONY: m-modes
m-modes: \
	.pipeline/030-m-modes-interpolated-calibrated-all \
	.pipeline/030-m-modes-interpolated-peeled-all \
	.pipeline/030-m-modes-interpolated-recalibrated-all

.PHONY: dirty-maps
dirty-maps: \
	.pipeline/031-dirty-map-calibrated-all \
	.pipeline/031-dirty-map-peeled-all \
	.pipeline/031-dirty-map-recalibrated-all \
	.pipeline/031-dirty-channel-maps-calibrated-all \
	.pipeline/031-dirty-channel-maps-peeled-all \
	.pipeline/031-dirty-channel-maps-recalibrated-all \
	.pipeline/031-dirty-map-interpolated-calibrated-all \
	.pipeline/031-dirty-map-interpolated-peeled-all \
	.pipeline/031-dirty-map-interpolated-recalibrated-all \
	.pipeline/031-dirty-channel-maps-interpolated-calibrated-all \
	.pipeline/031-dirty-channel-maps-interpolated-peeled-all \
	.pipeline/031-dirty-channel-maps-interpolated-recalibrated-all

.PHONY: filtered-maps
filtered-maps: \
	.pipeline/031-dirty-map-filtered-calibrated-all-mild \
	.pipeline/031-dirty-map-filtered-peeled-all-mild \
	.pipeline/031-dirty-map-filtered-recalibrated-all-mild \
	.pipeline/031-dirty-map-filtered-calibrated-all-moderate \
	.pipeline/031-dirty-map-filtered-peeled-all-moderate \
	.pipeline/031-dirty-map-filtered-recalibrated-all-moderate \
	.pipeline/031-dirty-map-filtered-calibrated-all-extreme \
	.pipeline/031-dirty-map-filtered-peeled-all-extreme \
	.pipeline/031-dirty-map-filtered-recalibrated-all-extreme

.PHONY: even-odd-maps
even-odd-maps: \
	.pipeline/031-dirty-map-interpolated-calibrated-even \
	.pipeline/031-dirty-map-interpolated-peeled-even \
	.pipeline/031-dirty-map-interpolated-recalibrated-even \
	.pipeline/031-dirty-map-interpolated-calibrated-odd \
	.pipeline/031-dirty-map-interpolated-peeled-odd \
	.pipeline/031-dirty-map-interpolated-recalibrated-odd \
	.pipeline/031-dirty-channel-maps-interpolated-calibrated-even \
	.pipeline/031-dirty-channel-maps-interpolated-peeled-even \
	.pipeline/031-dirty-channel-maps-interpolated-recalibrated-even \
	.pipeline/031-dirty-channel-maps-interpolated-calibrated-odd \
	.pipeline/031-dirty-channel-maps-interpolated-peeled-odd \
	.pipeline/031-dirty-channel-maps-interpolated-recalibrated-odd

.PHONY: day-night-maps
day-night-maps: \
	.pipeline/031-dirty-map-interpolated-calibrated-day \
	.pipeline/031-dirty-map-interpolated-peeled-day \
	.pipeline/031-dirty-map-interpolated-recalibrated-day \
	.pipeline/031-dirty-map-interpolated-calibrated-night \
	.pipeline/031-dirty-map-interpolated-peeled-night \
	.pipeline/031-dirty-map-interpolated-recalibrated-night \
	.pipeline/031-dirty-channel-maps-interpolated-calibrated-day \
	.pipeline/031-dirty-channel-maps-interpolated-peeled-day \
	.pipeline/031-dirty-channel-maps-interpolated-recalibrated-day \
	.pipeline/031-dirty-channel-maps-interpolated-calibrated-night \
	.pipeline/031-dirty-channel-maps-interpolated-peeled-night \
	.pipeline/031-dirty-channel-maps-interpolated-recalibrated-night

.PHONY: transfer-matrix
transfer-matrix: .pipeline/100-transfer-matrix

.PHONY: noise-covariance
noise-covariance: \
	.pipeline/102-noise-covariance-matrix-all \
	.pipeline/102-noise-covariance-matrix-odd \
	.pipeline/102-noise-covariance-matrix-even

.PHONY: sky-covariance
sky-covariance: \
	.pipeline/110-foreground-covariance-matrix \
	.pipeline/111-signal-covariance-matrix

.PHONY: angular-power-spectrum
angular-power-spectrum: \
	.pipeline/123-angular-quadratic-estimator

.PHONY: spherical-power-spectrum
spherical-power-spectrum: \
	.pipeline/122-quadratic-estimator-calibrated-all-moderate-spherical \
	.pipeline/122-quadratic-estimator-peeled-all-moderate-spherical \
	.pipeline/122-quadratic-estimator-peeled-all-mild-spherical \
	.pipeline/122-quadratic-estimator-peeled-all-extreme-spherical \
	.pipeline/122-quadratic-estimator-recalibrated-all-moderate-spherical

.PHONY: spherical-power-spectrum-even-odd
spherical-power-spectrum-even-odd: \
	.pipeline/122-quadratic-estimator-peeled-odd-moderate-spherical \
	.pipeline/122-quadratic-estimator-peeled-even-moderate-spherical \
	.pipeline/122-quadratic-estimator-peeled-odd-mild-spherical \
	.pipeline/122-quadratic-estimator-peeled-even-mild-spherical \
	.pipeline/122-quadratic-estimator-peeled-odd-extreme-spherical \
	.pipeline/122-quadratic-estimator-peeled-even-extreme-spherical

.PHONY: spherical-power-spectrum-day-night
spherical-power-spectrum-day-night: \
	.pipeline/122-quadratic-estimator-peeled-day-moderate-spherical \
	.pipeline/122-quadratic-estimator-peeled-night-moderate-spherical \
	.pipeline/122-quadratic-estimator-peeled-day-mild-spherical \
	.pipeline/122-quadratic-estimator-peeled-night-mild-spherical \
	.pipeline/122-quadratic-estimator-peeled-day-extreme-spherical \
	.pipeline/122-quadratic-estimator-peeled-night-extreme-spherical

.PHONY: cylindrical-power-spectrum-even-odd
cylindrical-power-spectrum-even-odd: \
	.pipeline/122-quadratic-estimator-peeled-odd-moderate-cylindrical \
	.pipeline/122-quadratic-estimator-peeled-even-moderate-cylindrical \
	.pipeline/122-quadratic-estimator-peeled-odd-mild-cylindrical \
	.pipeline/122-quadratic-estimator-peeled-even-mild-cylindrical \
	.pipeline/122-quadratic-estimator-peeled-odd-extreme-cylindrical \
	.pipeline/122-quadratic-estimator-peeled-even-extreme-cylindrical

.PHONY: sefd
sefd: .pipeline/200-measure-system-equivalent-flux-density

#.PHONY: signal-injection
#signal-injection: .pipeline/123-injected-quadratic-estimator

BIN=../../bin
LIB=../../lib
JULIA=julia-0.6 --color=yes -O3
LAUNCH=$(JULIA) -- $(BIN)/launch.jl

define launch
	$(LAUNCH) $(filter-out .pipeline/%,$^)
	touch $@
endef

define launch-remote
	$(LAUNCH) --remote-workers $(1) -- $(filter-out .pipeline/%,$^)
	touch $@
endef

# Some of these targets require significant resources on a machine and so we cannot reliably run
# anything in parallel. Currently there is no way to mark specific targets as ".NOTPARALLEL", so for
# now we have to mark the entire Makefile.
.NOTPARALLEL:

####################################################################################################
# DATA REDUCTION

.pipeline/000-raw-data: \
		$(LIB)/000-getdata.jl project.yml dada2ms.yml 000-getdata.yml
	$(call launch-remote,2)

.pipeline/001-raw-transposed-data: \
		$(LIB)/001-transpose.jl project.yml 001-transpose-raw.yml \
		.pipeline/000-raw-data
	$(call launch-remote,1)

.pipeline/002-flagged-raw-data: \
		$(LIB)/002-flag.jl project.yml 002-flag-raw.yml \
		.pipeline/000-raw-data \
		.pipeline/001-raw-transposed-data
	$(launch)

.pipeline/003-calibrated-data: \
		$(LIB)/003-calibrate.jl project.yml wsclean.yml 003-calibrate.yml \
		.pipeline/002-flagged-raw-data
	$(call launch-remote,1)

.pipeline/001-calibrated-transposed-data: \
		$(LIB)/001-transpose.jl project.yml 001-transpose-calibrated.yml \
		.pipeline/003-calibrated-data
	$(call launch-remote,1)

.pipeline/002-flagged-calibrated-data: \
		$(LIB)/002-flag.jl project.yml 002-flag-calibrated.yml \
		.pipeline/002-calibrated-data \
		.pipeline/001-calibrated-transposed-data
	$(launch)

.pipeline/010-fitrfi: \
		$(LIB)/010-fitrfi.jl project.yml wsclean.yml 010-fitrfi.yml \
		.pipeline/002-flagged-calibrated-data
	$(call launch-remote,1)

.pipeline/011-subrfi: \
		$(LIB)/011-subrfi.jl project.yml 011-subrfi.yml \
		.pipeline/001-flagged-calibrated-data \
		.pipeline/010-fitrfi
	$(call launch-remote,6)

.pipeline/020-peeled-data: \
		$(LIB)/020-peel.jl project.yml 020-peel.yml \
		.pipeline/011-subrfi
	$(call launch-remote,6)

.pipeline/001-peeled-transposed-data: \
		$(LIB)/001-transpose.jl project.yml 001-transpose-peeled.yml \
		.pipeline/020-peeled-data
	$(call launch-remote,1)

.pipeline/002-flagged-peeled-data: \
		$(LIB)/002-flag.jl project.yml 002-flag-peeled.yml \
		.pipeline/020-peeled-data \
		.pipeline/001-peeled-transposed-data
	$(launch)

.pipeline/040-recalibrate: \
		$(LIB)/040-recalibrate.jl project.yml wsclean.yml 040-recalibrate.yml \
		.pipeline/002-flagged-calibrated-data \
		.pipeline/032-predicted-visibilities-peeled
	$(call launch-remote,1)

.pipeline/041-recalibrate-apply: \
		$(LIB)/041-recalibrate-apply.jl project.yml 041-recalibrate-apply.yml \
		.pipeline/020-peeled-data \
		.pipeline/040-recalibrate
	$(call launch-remote,1)

.pipeline/001-recalibrated-transposed-data: \
		$(LIB)/001-transpose.jl project.yml 001-transpose-recalibrated.yml \
		.pipeline/041-recalibrate-apply
	$(call launch-remote,1)

####################################################################################################
# TRANSFER MATRIX AND NOISE COVARIANCE MATRICES

.pipeline/100-transfer-matrix: \
		$(LIB)/100-transfer-matrix.jl project.yml 100-transfer-matrix.yml \
		.pipeline/000-raw-data
	$(call launch-remote,4)

.pipeline/101-averaged-transfer-matrix: \
		$(LIB)/101-average-channels.jl project.yml 101-average-channels-transfer-matrix.yml \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/102-noise-covariance-matrix-%: \
		$(LIB)/102-noise-covariance-matrix.jl project.yml 102-noise-covariance-matrix-%.yml \
		.pipeline/000-raw-data \
		.pipeline/100-transfer-matrix \
		.pipeline/101-averaged-transfer-matrix
	$(call launch-remote,1)

.pipeline/110-foreground-covariance-matrix: \
		$(LIB)/110-foreground-covariance-matrix.jl project.yml 110-foreground-covariance-matrix.yml \
		.pipeline/101-averaged-m-modes
	$(launch)

.pipeline/111-signal-covariance-matrix: \
		$(LIB)/111-signal-covariance-matrix.jl project.yml 111-signal-covariance-matrix.yml \
		.pipeline/101-averaged-m-modes
	$(launch)

####################################################################################################
# QUADRATIC ESTIMATOR

#.pipeline/113-difference-even-odd: \
#		$(LIB)/113-difference-m-modes.jl project.yml 113-difference-even-odd.yml \
#		.pipeline/112-foreground-filter-moderate-odd \
#		.pipeline/112-foreground-filter-moderate-even
#	$(call launch-remote,2)

.pipeline/120-basis-covariance-matrices-angular: \
		$(LIB)/120-basis-covariance-matrices.jl project.yml 120-basis-covariance-matrices-angular.yml \
		.pipeline/101-averaged-m-modes-peeled-all
	$(call launch-remote,2)

.pipeline/120-basis-covariance-matrices-spherical: \
		$(LIB)/120-basis-covariance-matrices.jl project.yml 120-basis-covariance-matrices-spherical.yml \
		.pipeline/101-averaged-m-modes-peeled-all
	$(call launch-remote,2)

.pipeline/120-basis-covariance-matrices-cylindrical: \
		$(LIB)/120-basis-covariance-matrices.jl project.yml 120-basis-covariance-matrices-cylindrical.yml \
		.pipeline/101-averaged-m-modes-peeled-all
	$(call launch-remote,2)

.pipeline/123-angular-quadratic-estimator: \
		$(LIB)/123-angular-quadratic-estimator.jl project.yml 123-angular-quadratic-estimator.yml \
		.pipeline/103-full-rank-compression-peeled-all \
		.pipeline/110-foreground-covariance-matrix
	$(call launch-remote,1)

#.pipeline/121-quadratic-estimator-difference-even-odd: \
#		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-difference-even-odd.yml \
#	    .pipeline/113-difference-even-odd \
#		.pipeline/120-basis-covariance-matrices
#	$(call launch-remote,4)
#
#.pipeline/122-signal-injection: \
#		$(LIB)/122-signal-injection.jl project.yml 122-signal-injection.yml \
#		.pipeline/112-foreground-filter-moderate-all
#	$(launch)
#
#.pipeline/121-quadratic-estimator-signal-injection: \
#		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-signal-injection.yml \
#	    .pipeline/112-foreground-filter-moderate-all \
#		.pipeline/120-basis-covariance-matrices \
#		.pipeline/122-signal-injection
#	$(launch)

####################################################################################################
# MISC

.pipeline/200-measure-system-equivalent-flux-density: \
		$(LIB)/200-measure-system-equivalent-flux-density.jl project.yml \
		200-measure-system-equivalent-flux-density.yml \
		.pipeline/002-flagged-calibrated-data
	$(call launch-remote,4)

##.pipeline/033-difference-maps-even-odd: \
##		$(LIB)/033-difference-maps.jl project.yml 033-difference-maps-even-odd.yml \
##		.pipeline/032-dirty-map-odd \
##		.pipeline/032-dirty-map-even
##	$(launch)
#
#.pipeline/032-difference-channel-maps: \
#		$(LIB)/032-difference-maps.jl project.yml 032-difference-channel-maps.yml \
#		.pipeline/031-dirty-channel-maps
#	$(launch)
#
#.pipeline/032-difference-channel-maps-unpeeled: \
#		$(LIB)/032-difference-maps.jl project.yml 032-difference-channel-maps-unpeeled.yml \
#		.pipeline/031-dirty-channel-maps-unpeeled
#	$(launch)

####################################################################################################
# AUTO-GENERATED RULES

include AutoGenerated.mk

