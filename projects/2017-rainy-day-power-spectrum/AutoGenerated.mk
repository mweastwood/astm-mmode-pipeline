# This file was auto-generated. Do not edit directly!

.pipeline/030-m-modes-calibrated-all: \
		$(LIB)/030-getmmodes.jl project.yml generated-config-files/030-getmmodes-calibrated-all.yml \
		.pipeline/001-calibrated-transposed-data \
		.pipeline/002-flagged-calibrated-data \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/030-m-modes-interpolated-calibrated-all: \
		$(LIB)/030-getmmodes.jl project.yml generated-config-files/030-getmmodes-interpolated-calibrated-all.yml \
		.pipeline/001-calibrated-transposed-data \
		.pipeline/002-flagged-calibrated-data \
		.pipeline/032-predicted-visibilities-calibrated \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-calibrated-all: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-calibrated-all.yml \
		.pipeline/030-m-modes-calibrated-all \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-calibrated-all: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-channels-calibrated-all.yml \
		.pipeline/030-m-modes-calibrated-all \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-interpolated-calibrated-all: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-interpolated-calibrated-all.yml \
		.pipeline/030-m-modes-interpolated-calibrated-all \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-interpolated-calibrated-all: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-channels-interpolated-calibrated-all.yml \
		.pipeline/030-m-modes-interpolated-calibrated-all \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/101-averaged-m-modes-calibrated-all: \
		$(LIB)/101-average-channels.jl project.yml generated-config-files/101-average-channels-m-modes-calibrated-all.yml \
		.pipeline/030-m-modes-interpolated-calibrated-all
	$(call launch-remote,1)

.pipeline/103-full-rank-compression-calibrated-all: \
		$(LIB)/103-full-rank-compress.jl project.yml generated-config-files/103-full-rank-compress-calibrated-all.yml \
		.pipeline/101-averaged-m-modes-calibrated-all \
		.pipeline/101-averaged-transfer-matrix \
		.pipeline/102-noise-covariance-matrix-all
	$(call launch-remote,1)

.pipeline/112-foreground-filter-calibrated-all-extreme: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-calibrated-all-extreme.yml \
		.pipeline/103-full-rank-compression-calibrated-all \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-calibrated-all-extreme: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-calibrated-all-extreme.yml \
		.pipeline/112-foreground-filter-calibrated-all-extreme
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-calibrated-all-extreme-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-all-extreme-spherical.yml \
		.pipeline/112-foreground-filter-calibrated-all-extreme \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-all-extreme-spherical
	$(launch)

.pipeline/122-quadratic-estimator-calibrated-all-extreme-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-all-extreme-cylindrical.yml \
		.pipeline/112-foreground-filter-calibrated-all-extreme \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-all-extreme-cylindrical
	$(launch)

.pipeline/112-foreground-filter-calibrated-all-moderate: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-calibrated-all-moderate.yml \
		.pipeline/103-full-rank-compression-calibrated-all \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-calibrated-all-moderate: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-calibrated-all-moderate.yml \
		.pipeline/112-foreground-filter-calibrated-all-moderate
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-calibrated-all-moderate-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-all-moderate-spherical.yml \
		.pipeline/112-foreground-filter-calibrated-all-moderate \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-all-moderate-spherical
	$(launch)

.pipeline/122-quadratic-estimator-calibrated-all-moderate-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-all-moderate-cylindrical.yml \
		.pipeline/112-foreground-filter-calibrated-all-moderate \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-all-moderate-cylindrical
	$(launch)

.pipeline/112-foreground-filter-calibrated-all-mild: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-calibrated-all-mild.yml \
		.pipeline/103-full-rank-compression-calibrated-all \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-calibrated-all-mild: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-calibrated-all-mild.yml \
		.pipeline/112-foreground-filter-calibrated-all-mild
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-calibrated-all-mild-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-all-mild-spherical.yml \
		.pipeline/112-foreground-filter-calibrated-all-mild \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-all-mild-spherical
	$(launch)

.pipeline/122-quadratic-estimator-calibrated-all-mild-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-all-mild-cylindrical.yml \
		.pipeline/112-foreground-filter-calibrated-all-mild \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-all-mild-cylindrical
	$(launch)

.pipeline/112-foreground-filter-calibrated-all-none: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-calibrated-all-none.yml \
		.pipeline/103-full-rank-compression-calibrated-all \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-calibrated-all-none: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-calibrated-all-none.yml \
		.pipeline/112-foreground-filter-calibrated-all-none
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-calibrated-all-none-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-all-none-spherical.yml \
		.pipeline/112-foreground-filter-calibrated-all-none \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-all-none-spherical
	$(launch)

.pipeline/122-quadratic-estimator-calibrated-all-none-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-all-none-cylindrical.yml \
		.pipeline/112-foreground-filter-calibrated-all-none \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-all-none-cylindrical
	$(launch)

.pipeline/030-m-modes-calibrated-odd: \
		$(LIB)/030-getmmodes.jl project.yml generated-config-files/030-getmmodes-calibrated-odd.yml \
		.pipeline/001-calibrated-transposed-data \
		.pipeline/002-flagged-calibrated-data \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/030-m-modes-interpolated-calibrated-odd: \
		$(LIB)/030-getmmodes.jl project.yml generated-config-files/030-getmmodes-interpolated-calibrated-odd.yml \
		.pipeline/001-calibrated-transposed-data \
		.pipeline/002-flagged-calibrated-data \
		.pipeline/032-predicted-visibilities-calibrated \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-calibrated-odd: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-calibrated-odd.yml \
		.pipeline/030-m-modes-calibrated-odd \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-calibrated-odd: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-channels-calibrated-odd.yml \
		.pipeline/030-m-modes-calibrated-odd \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-interpolated-calibrated-odd: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-interpolated-calibrated-odd.yml \
		.pipeline/030-m-modes-interpolated-calibrated-odd \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-interpolated-calibrated-odd: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-channels-interpolated-calibrated-odd.yml \
		.pipeline/030-m-modes-interpolated-calibrated-odd \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/101-averaged-m-modes-calibrated-odd: \
		$(LIB)/101-average-channels.jl project.yml generated-config-files/101-average-channels-m-modes-calibrated-odd.yml \
		.pipeline/030-m-modes-interpolated-calibrated-odd
	$(call launch-remote,1)

.pipeline/103-full-rank-compression-calibrated-odd: \
		$(LIB)/103-full-rank-compress.jl project.yml generated-config-files/103-full-rank-compress-calibrated-odd.yml \
		.pipeline/101-averaged-m-modes-calibrated-odd \
		.pipeline/101-averaged-transfer-matrix \
		.pipeline/102-noise-covariance-matrix-odd
	$(call launch-remote,1)

.pipeline/112-foreground-filter-calibrated-odd-extreme: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-calibrated-odd-extreme.yml \
		.pipeline/103-full-rank-compression-calibrated-odd \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-calibrated-odd-extreme: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-calibrated-odd-extreme.yml \
		.pipeline/112-foreground-filter-calibrated-odd-extreme
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-calibrated-odd-extreme-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-odd-extreme-spherical.yml \
		.pipeline/112-foreground-filter-calibrated-odd-extreme \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-odd-extreme-spherical
	$(launch)

.pipeline/122-quadratic-estimator-calibrated-odd-extreme-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-odd-extreme-cylindrical.yml \
		.pipeline/112-foreground-filter-calibrated-odd-extreme \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-odd-extreme-cylindrical
	$(launch)

.pipeline/112-foreground-filter-calibrated-odd-moderate: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-calibrated-odd-moderate.yml \
		.pipeline/103-full-rank-compression-calibrated-odd \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-calibrated-odd-moderate: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-calibrated-odd-moderate.yml \
		.pipeline/112-foreground-filter-calibrated-odd-moderate
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-calibrated-odd-moderate-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-odd-moderate-spherical.yml \
		.pipeline/112-foreground-filter-calibrated-odd-moderate \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-odd-moderate-spherical
	$(launch)

.pipeline/122-quadratic-estimator-calibrated-odd-moderate-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-odd-moderate-cylindrical.yml \
		.pipeline/112-foreground-filter-calibrated-odd-moderate \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-odd-moderate-cylindrical
	$(launch)

.pipeline/112-foreground-filter-calibrated-odd-mild: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-calibrated-odd-mild.yml \
		.pipeline/103-full-rank-compression-calibrated-odd \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-calibrated-odd-mild: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-calibrated-odd-mild.yml \
		.pipeline/112-foreground-filter-calibrated-odd-mild
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-calibrated-odd-mild-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-odd-mild-spherical.yml \
		.pipeline/112-foreground-filter-calibrated-odd-mild \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-odd-mild-spherical
	$(launch)

.pipeline/122-quadratic-estimator-calibrated-odd-mild-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-odd-mild-cylindrical.yml \
		.pipeline/112-foreground-filter-calibrated-odd-mild \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-odd-mild-cylindrical
	$(launch)

.pipeline/112-foreground-filter-calibrated-odd-none: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-calibrated-odd-none.yml \
		.pipeline/103-full-rank-compression-calibrated-odd \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-calibrated-odd-none: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-calibrated-odd-none.yml \
		.pipeline/112-foreground-filter-calibrated-odd-none
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-calibrated-odd-none-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-odd-none-spherical.yml \
		.pipeline/112-foreground-filter-calibrated-odd-none \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-odd-none-spherical
	$(launch)

.pipeline/122-quadratic-estimator-calibrated-odd-none-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-odd-none-cylindrical.yml \
		.pipeline/112-foreground-filter-calibrated-odd-none \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-odd-none-cylindrical
	$(launch)

.pipeline/030-m-modes-calibrated-even: \
		$(LIB)/030-getmmodes.jl project.yml generated-config-files/030-getmmodes-calibrated-even.yml \
		.pipeline/001-calibrated-transposed-data \
		.pipeline/002-flagged-calibrated-data \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/030-m-modes-interpolated-calibrated-even: \
		$(LIB)/030-getmmodes.jl project.yml generated-config-files/030-getmmodes-interpolated-calibrated-even.yml \
		.pipeline/001-calibrated-transposed-data \
		.pipeline/002-flagged-calibrated-data \
		.pipeline/032-predicted-visibilities-calibrated \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-calibrated-even: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-calibrated-even.yml \
		.pipeline/030-m-modes-calibrated-even \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-calibrated-even: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-channels-calibrated-even.yml \
		.pipeline/030-m-modes-calibrated-even \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-interpolated-calibrated-even: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-interpolated-calibrated-even.yml \
		.pipeline/030-m-modes-interpolated-calibrated-even \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-interpolated-calibrated-even: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-channels-interpolated-calibrated-even.yml \
		.pipeline/030-m-modes-interpolated-calibrated-even \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/101-averaged-m-modes-calibrated-even: \
		$(LIB)/101-average-channels.jl project.yml generated-config-files/101-average-channels-m-modes-calibrated-even.yml \
		.pipeline/030-m-modes-interpolated-calibrated-even
	$(call launch-remote,1)

.pipeline/103-full-rank-compression-calibrated-even: \
		$(LIB)/103-full-rank-compress.jl project.yml generated-config-files/103-full-rank-compress-calibrated-even.yml \
		.pipeline/101-averaged-m-modes-calibrated-even \
		.pipeline/101-averaged-transfer-matrix \
		.pipeline/102-noise-covariance-matrix-even
	$(call launch-remote,1)

.pipeline/112-foreground-filter-calibrated-even-extreme: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-calibrated-even-extreme.yml \
		.pipeline/103-full-rank-compression-calibrated-even \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-calibrated-even-extreme: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-calibrated-even-extreme.yml \
		.pipeline/112-foreground-filter-calibrated-even-extreme
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-calibrated-even-extreme-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-even-extreme-spherical.yml \
		.pipeline/112-foreground-filter-calibrated-even-extreme \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-even-extreme-spherical
	$(launch)

.pipeline/122-quadratic-estimator-calibrated-even-extreme-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-even-extreme-cylindrical.yml \
		.pipeline/112-foreground-filter-calibrated-even-extreme \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-even-extreme-cylindrical
	$(launch)

.pipeline/112-foreground-filter-calibrated-even-moderate: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-calibrated-even-moderate.yml \
		.pipeline/103-full-rank-compression-calibrated-even \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-calibrated-even-moderate: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-calibrated-even-moderate.yml \
		.pipeline/112-foreground-filter-calibrated-even-moderate
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-calibrated-even-moderate-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-even-moderate-spherical.yml \
		.pipeline/112-foreground-filter-calibrated-even-moderate \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-even-moderate-spherical
	$(launch)

.pipeline/122-quadratic-estimator-calibrated-even-moderate-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-even-moderate-cylindrical.yml \
		.pipeline/112-foreground-filter-calibrated-even-moderate \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-even-moderate-cylindrical
	$(launch)

.pipeline/112-foreground-filter-calibrated-even-mild: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-calibrated-even-mild.yml \
		.pipeline/103-full-rank-compression-calibrated-even \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-calibrated-even-mild: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-calibrated-even-mild.yml \
		.pipeline/112-foreground-filter-calibrated-even-mild
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-calibrated-even-mild-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-even-mild-spherical.yml \
		.pipeline/112-foreground-filter-calibrated-even-mild \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-even-mild-spherical
	$(launch)

.pipeline/122-quadratic-estimator-calibrated-even-mild-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-even-mild-cylindrical.yml \
		.pipeline/112-foreground-filter-calibrated-even-mild \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-even-mild-cylindrical
	$(launch)

.pipeline/112-foreground-filter-calibrated-even-none: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-calibrated-even-none.yml \
		.pipeline/103-full-rank-compression-calibrated-even \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-calibrated-even-none: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-calibrated-even-none.yml \
		.pipeline/112-foreground-filter-calibrated-even-none
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-calibrated-even-none-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-even-none-spherical.yml \
		.pipeline/112-foreground-filter-calibrated-even-none \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-even-none-spherical
	$(launch)

.pipeline/122-quadratic-estimator-calibrated-even-none-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-even-none-cylindrical.yml \
		.pipeline/112-foreground-filter-calibrated-even-none \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-even-none-cylindrical
	$(launch)

.pipeline/030-m-modes-calibrated-day: \
		$(LIB)/030-getmmodes.jl project.yml generated-config-files/030-getmmodes-calibrated-day.yml \
		.pipeline/001-calibrated-transposed-data \
		.pipeline/002-flagged-calibrated-data \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/030-m-modes-interpolated-calibrated-day: \
		$(LIB)/030-getmmodes.jl project.yml generated-config-files/030-getmmodes-interpolated-calibrated-day.yml \
		.pipeline/001-calibrated-transposed-data \
		.pipeline/002-flagged-calibrated-data \
		.pipeline/032-predicted-visibilities-calibrated \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-calibrated-day: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-calibrated-day.yml \
		.pipeline/030-m-modes-calibrated-day \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-calibrated-day: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-channels-calibrated-day.yml \
		.pipeline/030-m-modes-calibrated-day \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-interpolated-calibrated-day: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-interpolated-calibrated-day.yml \
		.pipeline/030-m-modes-interpolated-calibrated-day \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-interpolated-calibrated-day: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-channels-interpolated-calibrated-day.yml \
		.pipeline/030-m-modes-interpolated-calibrated-day \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/101-averaged-m-modes-calibrated-day: \
		$(LIB)/101-average-channels.jl project.yml generated-config-files/101-average-channels-m-modes-calibrated-day.yml \
		.pipeline/030-m-modes-interpolated-calibrated-day
	$(call launch-remote,1)

.pipeline/103-full-rank-compression-calibrated-day: \
		$(LIB)/103-full-rank-compress.jl project.yml generated-config-files/103-full-rank-compress-calibrated-day.yml \
		.pipeline/101-averaged-m-modes-calibrated-day \
		.pipeline/101-averaged-transfer-matrix \
		.pipeline/102-noise-covariance-matrix-day
	$(call launch-remote,1)

.pipeline/112-foreground-filter-calibrated-day-extreme: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-calibrated-day-extreme.yml \
		.pipeline/103-full-rank-compression-calibrated-day \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-calibrated-day-extreme: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-calibrated-day-extreme.yml \
		.pipeline/112-foreground-filter-calibrated-day-extreme
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-calibrated-day-extreme-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-day-extreme-spherical.yml \
		.pipeline/112-foreground-filter-calibrated-day-extreme \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-day-extreme-spherical
	$(launch)

.pipeline/122-quadratic-estimator-calibrated-day-extreme-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-day-extreme-cylindrical.yml \
		.pipeline/112-foreground-filter-calibrated-day-extreme \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-day-extreme-cylindrical
	$(launch)

.pipeline/112-foreground-filter-calibrated-day-moderate: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-calibrated-day-moderate.yml \
		.pipeline/103-full-rank-compression-calibrated-day \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-calibrated-day-moderate: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-calibrated-day-moderate.yml \
		.pipeline/112-foreground-filter-calibrated-day-moderate
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-calibrated-day-moderate-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-day-moderate-spherical.yml \
		.pipeline/112-foreground-filter-calibrated-day-moderate \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-day-moderate-spherical
	$(launch)

.pipeline/122-quadratic-estimator-calibrated-day-moderate-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-day-moderate-cylindrical.yml \
		.pipeline/112-foreground-filter-calibrated-day-moderate \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-day-moderate-cylindrical
	$(launch)

.pipeline/112-foreground-filter-calibrated-day-mild: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-calibrated-day-mild.yml \
		.pipeline/103-full-rank-compression-calibrated-day \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-calibrated-day-mild: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-calibrated-day-mild.yml \
		.pipeline/112-foreground-filter-calibrated-day-mild
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-calibrated-day-mild-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-day-mild-spherical.yml \
		.pipeline/112-foreground-filter-calibrated-day-mild \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-day-mild-spherical
	$(launch)

.pipeline/122-quadratic-estimator-calibrated-day-mild-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-day-mild-cylindrical.yml \
		.pipeline/112-foreground-filter-calibrated-day-mild \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-day-mild-cylindrical
	$(launch)

.pipeline/112-foreground-filter-calibrated-day-none: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-calibrated-day-none.yml \
		.pipeline/103-full-rank-compression-calibrated-day \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-calibrated-day-none: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-calibrated-day-none.yml \
		.pipeline/112-foreground-filter-calibrated-day-none
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-calibrated-day-none-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-day-none-spherical.yml \
		.pipeline/112-foreground-filter-calibrated-day-none \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-day-none-spherical
	$(launch)

.pipeline/122-quadratic-estimator-calibrated-day-none-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-day-none-cylindrical.yml \
		.pipeline/112-foreground-filter-calibrated-day-none \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-day-none-cylindrical
	$(launch)

.pipeline/030-m-modes-calibrated-night: \
		$(LIB)/030-getmmodes.jl project.yml generated-config-files/030-getmmodes-calibrated-night.yml \
		.pipeline/001-calibrated-transposed-data \
		.pipeline/002-flagged-calibrated-data \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/030-m-modes-interpolated-calibrated-night: \
		$(LIB)/030-getmmodes.jl project.yml generated-config-files/030-getmmodes-interpolated-calibrated-night.yml \
		.pipeline/001-calibrated-transposed-data \
		.pipeline/002-flagged-calibrated-data \
		.pipeline/032-predicted-visibilities-calibrated \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-calibrated-night: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-calibrated-night.yml \
		.pipeline/030-m-modes-calibrated-night \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-calibrated-night: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-channels-calibrated-night.yml \
		.pipeline/030-m-modes-calibrated-night \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-interpolated-calibrated-night: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-interpolated-calibrated-night.yml \
		.pipeline/030-m-modes-interpolated-calibrated-night \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-interpolated-calibrated-night: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-channels-interpolated-calibrated-night.yml \
		.pipeline/030-m-modes-interpolated-calibrated-night \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/101-averaged-m-modes-calibrated-night: \
		$(LIB)/101-average-channels.jl project.yml generated-config-files/101-average-channels-m-modes-calibrated-night.yml \
		.pipeline/030-m-modes-interpolated-calibrated-night
	$(call launch-remote,1)

.pipeline/103-full-rank-compression-calibrated-night: \
		$(LIB)/103-full-rank-compress.jl project.yml generated-config-files/103-full-rank-compress-calibrated-night.yml \
		.pipeline/101-averaged-m-modes-calibrated-night \
		.pipeline/101-averaged-transfer-matrix \
		.pipeline/102-noise-covariance-matrix-night
	$(call launch-remote,1)

.pipeline/112-foreground-filter-calibrated-night-extreme: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-calibrated-night-extreme.yml \
		.pipeline/103-full-rank-compression-calibrated-night \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-calibrated-night-extreme: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-calibrated-night-extreme.yml \
		.pipeline/112-foreground-filter-calibrated-night-extreme
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-calibrated-night-extreme-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-night-extreme-spherical.yml \
		.pipeline/112-foreground-filter-calibrated-night-extreme \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-night-extreme-spherical
	$(launch)

.pipeline/122-quadratic-estimator-calibrated-night-extreme-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-night-extreme-cylindrical.yml \
		.pipeline/112-foreground-filter-calibrated-night-extreme \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-night-extreme-cylindrical
	$(launch)

.pipeline/112-foreground-filter-calibrated-night-moderate: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-calibrated-night-moderate.yml \
		.pipeline/103-full-rank-compression-calibrated-night \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-calibrated-night-moderate: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-calibrated-night-moderate.yml \
		.pipeline/112-foreground-filter-calibrated-night-moderate
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-calibrated-night-moderate-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-night-moderate-spherical.yml \
		.pipeline/112-foreground-filter-calibrated-night-moderate \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-night-moderate-spherical
	$(launch)

.pipeline/122-quadratic-estimator-calibrated-night-moderate-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-night-moderate-cylindrical.yml \
		.pipeline/112-foreground-filter-calibrated-night-moderate \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-night-moderate-cylindrical
	$(launch)

.pipeline/112-foreground-filter-calibrated-night-mild: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-calibrated-night-mild.yml \
		.pipeline/103-full-rank-compression-calibrated-night \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-calibrated-night-mild: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-calibrated-night-mild.yml \
		.pipeline/112-foreground-filter-calibrated-night-mild
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-calibrated-night-mild-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-night-mild-spherical.yml \
		.pipeline/112-foreground-filter-calibrated-night-mild \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-night-mild-spherical
	$(launch)

.pipeline/122-quadratic-estimator-calibrated-night-mild-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-night-mild-cylindrical.yml \
		.pipeline/112-foreground-filter-calibrated-night-mild \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-night-mild-cylindrical
	$(launch)

.pipeline/112-foreground-filter-calibrated-night-none: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-calibrated-night-none.yml \
		.pipeline/103-full-rank-compression-calibrated-night \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-calibrated-night-none: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-calibrated-night-none.yml \
		.pipeline/112-foreground-filter-calibrated-night-none
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-calibrated-night-none-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-night-none-spherical.yml \
		.pipeline/112-foreground-filter-calibrated-night-none \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-night-none-spherical
	$(launch)

.pipeline/122-quadratic-estimator-calibrated-night-none-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-calibrated-night-none-cylindrical.yml \
		.pipeline/112-foreground-filter-calibrated-night-none \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-night-none-cylindrical
	$(launch)

.pipeline/032-predicted-visibilities-calibrated: \
		$(LIB)/032-predict-visibilities.jl project.yml generated-config-files/032-predict-visibilities-calibrated.yml \
		.pipeline/031-dirty-map-calibrated-all \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/101-averaged-m-modes-predicted-calibrated: \
		$(LIB)/101-average-channels.jl project.yml generated-config-files/101-average-channels-m-modes-predicted-calibrated.yml \
		.pipeline/032-predicted-visibilities-calibrated
	$(call launch-remote,1)

.pipeline/103-full-rank-compression-predicted-calibrated: \
		$(LIB)/103-full-rank-compress.jl project.yml generated-config-files/103-full-rank-compress-predicted-calibrated.yml \
		.pipeline/101-averaged-m-modes-predicted-calibrated \
		.pipeline/101-averaged-transfer-matrix \
		.pipeline/102-noise-covariance-matrix-all
	$(call launch-remote,1)

.pipeline/112-foreground-filter-predicted-calibrated-extreme: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-predicted-calibrated-extreme.yml \
		.pipeline/103-full-rank-compression-predicted-calibrated \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/112-foreground-filter-predicted-calibrated-moderate: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-predicted-calibrated-moderate.yml \
		.pipeline/103-full-rank-compression-predicted-calibrated \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/112-foreground-filter-predicted-calibrated-mild: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-predicted-calibrated-mild.yml \
		.pipeline/103-full-rank-compression-predicted-calibrated \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/112-foreground-filter-predicted-calibrated-none: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-predicted-calibrated-none.yml \
		.pipeline/103-full-rank-compression-predicted-calibrated \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/030-m-modes-peeled-all: \
		$(LIB)/030-getmmodes.jl project.yml generated-config-files/030-getmmodes-peeled-all.yml \
		.pipeline/001-peeled-transposed-data \
		.pipeline/002-flagged-peeled-data \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/030-m-modes-interpolated-peeled-all: \
		$(LIB)/030-getmmodes.jl project.yml generated-config-files/030-getmmodes-interpolated-peeled-all.yml \
		.pipeline/001-peeled-transposed-data \
		.pipeline/002-flagged-peeled-data \
		.pipeline/032-predicted-visibilities-peeled \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-peeled-all: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-peeled-all.yml \
		.pipeline/030-m-modes-peeled-all \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-peeled-all: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-channels-peeled-all.yml \
		.pipeline/030-m-modes-peeled-all \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-interpolated-peeled-all: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-interpolated-peeled-all.yml \
		.pipeline/030-m-modes-interpolated-peeled-all \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-interpolated-peeled-all: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-channels-interpolated-peeled-all.yml \
		.pipeline/030-m-modes-interpolated-peeled-all \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/101-averaged-m-modes-peeled-all: \
		$(LIB)/101-average-channels.jl project.yml generated-config-files/101-average-channels-m-modes-peeled-all.yml \
		.pipeline/030-m-modes-interpolated-peeled-all
	$(call launch-remote,1)

.pipeline/103-full-rank-compression-peeled-all: \
		$(LIB)/103-full-rank-compress.jl project.yml generated-config-files/103-full-rank-compress-peeled-all.yml \
		.pipeline/101-averaged-m-modes-peeled-all \
		.pipeline/101-averaged-transfer-matrix \
		.pipeline/102-noise-covariance-matrix-all
	$(call launch-remote,1)

.pipeline/112-foreground-filter-peeled-all-extreme: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-peeled-all-extreme.yml \
		.pipeline/103-full-rank-compression-peeled-all \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-peeled-all-extreme: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-peeled-all-extreme.yml \
		.pipeline/112-foreground-filter-peeled-all-extreme
	$(call launch-remote,1)

.pipeline/121-fisher-matrix-all-extreme-spherical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-all-extreme-spherical.yml \
		.pipeline/112-foreground-filter-peeled-all-extreme \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,4)

.pipeline/122-quadratic-estimator-peeled-all-extreme-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-all-extreme-spherical.yml \
		.pipeline/112-foreground-filter-peeled-all-extreme \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-all-extreme-spherical
	$(launch)

.pipeline/121-fisher-matrix-all-extreme-cylindrical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-all-extreme-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-all-extreme \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,4)

.pipeline/122-quadratic-estimator-peeled-all-extreme-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-all-extreme-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-all-extreme \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-all-extreme-cylindrical
	$(launch)

.pipeline/112-foreground-filter-peeled-all-moderate: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-peeled-all-moderate.yml \
		.pipeline/103-full-rank-compression-peeled-all \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-peeled-all-moderate: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-peeled-all-moderate.yml \
		.pipeline/112-foreground-filter-peeled-all-moderate
	$(call launch-remote,1)

.pipeline/121-fisher-matrix-all-moderate-spherical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-all-moderate-spherical.yml \
		.pipeline/112-foreground-filter-peeled-all-moderate \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,4)

.pipeline/122-quadratic-estimator-peeled-all-moderate-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-all-moderate-spherical.yml \
		.pipeline/112-foreground-filter-peeled-all-moderate \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-all-moderate-spherical
	$(launch)

.pipeline/121-fisher-matrix-all-moderate-cylindrical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-all-moderate-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-all-moderate \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,4)

.pipeline/122-quadratic-estimator-peeled-all-moderate-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-all-moderate-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-all-moderate \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-all-moderate-cylindrical
	$(launch)

.pipeline/112-foreground-filter-peeled-all-mild: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-peeled-all-mild.yml \
		.pipeline/103-full-rank-compression-peeled-all \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-peeled-all-mild: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-peeled-all-mild.yml \
		.pipeline/112-foreground-filter-peeled-all-mild
	$(call launch-remote,1)

.pipeline/121-fisher-matrix-all-mild-spherical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-all-mild-spherical.yml \
		.pipeline/112-foreground-filter-peeled-all-mild \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,2)

.pipeline/122-quadratic-estimator-peeled-all-mild-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-all-mild-spherical.yml \
		.pipeline/112-foreground-filter-peeled-all-mild \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-all-mild-spherical
	$(launch)

.pipeline/121-fisher-matrix-all-mild-cylindrical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-all-mild-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-all-mild \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,2)

.pipeline/122-quadratic-estimator-peeled-all-mild-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-all-mild-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-all-mild \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-all-mild-cylindrical
	$(launch)

.pipeline/112-foreground-filter-peeled-all-none: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-peeled-all-none.yml \
		.pipeline/103-full-rank-compression-peeled-all \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-peeled-all-none: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-peeled-all-none.yml \
		.pipeline/112-foreground-filter-peeled-all-none
	$(call launch-remote,1)

.pipeline/121-fisher-matrix-all-none-spherical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-all-none-spherical.yml \
		.pipeline/112-foreground-filter-peeled-all-none \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-peeled-all-none-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-all-none-spherical.yml \
		.pipeline/112-foreground-filter-peeled-all-none \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-all-none-spherical
	$(launch)

.pipeline/121-fisher-matrix-all-none-cylindrical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-all-none-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-all-none \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-peeled-all-none-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-all-none-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-all-none \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-all-none-cylindrical
	$(launch)

.pipeline/030-m-modes-peeled-odd: \
		$(LIB)/030-getmmodes.jl project.yml generated-config-files/030-getmmodes-peeled-odd.yml \
		.pipeline/001-peeled-transposed-data \
		.pipeline/002-flagged-peeled-data \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/030-m-modes-interpolated-peeled-odd: \
		$(LIB)/030-getmmodes.jl project.yml generated-config-files/030-getmmodes-interpolated-peeled-odd.yml \
		.pipeline/001-peeled-transposed-data \
		.pipeline/002-flagged-peeled-data \
		.pipeline/032-predicted-visibilities-peeled \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-peeled-odd: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-peeled-odd.yml \
		.pipeline/030-m-modes-peeled-odd \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-peeled-odd: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-channels-peeled-odd.yml \
		.pipeline/030-m-modes-peeled-odd \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-interpolated-peeled-odd: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-interpolated-peeled-odd.yml \
		.pipeline/030-m-modes-interpolated-peeled-odd \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-interpolated-peeled-odd: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-channels-interpolated-peeled-odd.yml \
		.pipeline/030-m-modes-interpolated-peeled-odd \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/101-averaged-m-modes-peeled-odd: \
		$(LIB)/101-average-channels.jl project.yml generated-config-files/101-average-channels-m-modes-peeled-odd.yml \
		.pipeline/030-m-modes-interpolated-peeled-odd
	$(call launch-remote,1)

.pipeline/103-full-rank-compression-peeled-odd: \
		$(LIB)/103-full-rank-compress.jl project.yml generated-config-files/103-full-rank-compress-peeled-odd.yml \
		.pipeline/101-averaged-m-modes-peeled-odd \
		.pipeline/101-averaged-transfer-matrix \
		.pipeline/102-noise-covariance-matrix-odd
	$(call launch-remote,1)

.pipeline/112-foreground-filter-peeled-odd-extreme: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-peeled-odd-extreme.yml \
		.pipeline/103-full-rank-compression-peeled-odd \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-peeled-odd-extreme: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-peeled-odd-extreme.yml \
		.pipeline/112-foreground-filter-peeled-odd-extreme
	$(call launch-remote,1)

.pipeline/121-fisher-matrix-odd-extreme-spherical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-odd-extreme-spherical.yml \
		.pipeline/112-foreground-filter-peeled-odd-extreme \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,4)

.pipeline/122-quadratic-estimator-peeled-odd-extreme-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-odd-extreme-spherical.yml \
		.pipeline/112-foreground-filter-peeled-odd-extreme \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-odd-extreme-spherical
	$(launch)

.pipeline/121-fisher-matrix-odd-extreme-cylindrical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-odd-extreme-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-odd-extreme \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,4)

.pipeline/122-quadratic-estimator-peeled-odd-extreme-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-odd-extreme-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-odd-extreme \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-odd-extreme-cylindrical
	$(launch)

.pipeline/112-foreground-filter-peeled-odd-moderate: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-peeled-odd-moderate.yml \
		.pipeline/103-full-rank-compression-peeled-odd \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-peeled-odd-moderate: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-peeled-odd-moderate.yml \
		.pipeline/112-foreground-filter-peeled-odd-moderate
	$(call launch-remote,1)

.pipeline/121-fisher-matrix-odd-moderate-spherical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-odd-moderate-spherical.yml \
		.pipeline/112-foreground-filter-peeled-odd-moderate \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,4)

.pipeline/122-quadratic-estimator-peeled-odd-moderate-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-odd-moderate-spherical.yml \
		.pipeline/112-foreground-filter-peeled-odd-moderate \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-odd-moderate-spherical
	$(launch)

.pipeline/121-fisher-matrix-odd-moderate-cylindrical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-odd-moderate-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-odd-moderate \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,4)

.pipeline/122-quadratic-estimator-peeled-odd-moderate-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-odd-moderate-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-odd-moderate \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-odd-moderate-cylindrical
	$(launch)

.pipeline/112-foreground-filter-peeled-odd-mild: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-peeled-odd-mild.yml \
		.pipeline/103-full-rank-compression-peeled-odd \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-peeled-odd-mild: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-peeled-odd-mild.yml \
		.pipeline/112-foreground-filter-peeled-odd-mild
	$(call launch-remote,1)

.pipeline/121-fisher-matrix-odd-mild-spherical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-odd-mild-spherical.yml \
		.pipeline/112-foreground-filter-peeled-odd-mild \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,2)

.pipeline/122-quadratic-estimator-peeled-odd-mild-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-odd-mild-spherical.yml \
		.pipeline/112-foreground-filter-peeled-odd-mild \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-odd-mild-spherical
	$(launch)

.pipeline/121-fisher-matrix-odd-mild-cylindrical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-odd-mild-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-odd-mild \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,2)

.pipeline/122-quadratic-estimator-peeled-odd-mild-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-odd-mild-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-odd-mild \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-odd-mild-cylindrical
	$(launch)

.pipeline/112-foreground-filter-peeled-odd-none: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-peeled-odd-none.yml \
		.pipeline/103-full-rank-compression-peeled-odd \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-peeled-odd-none: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-peeled-odd-none.yml \
		.pipeline/112-foreground-filter-peeled-odd-none
	$(call launch-remote,1)

.pipeline/121-fisher-matrix-odd-none-spherical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-odd-none-spherical.yml \
		.pipeline/112-foreground-filter-peeled-odd-none \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-peeled-odd-none-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-odd-none-spherical.yml \
		.pipeline/112-foreground-filter-peeled-odd-none \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-odd-none-spherical
	$(launch)

.pipeline/121-fisher-matrix-odd-none-cylindrical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-odd-none-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-odd-none \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-peeled-odd-none-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-odd-none-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-odd-none \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-odd-none-cylindrical
	$(launch)

.pipeline/030-m-modes-peeled-even: \
		$(LIB)/030-getmmodes.jl project.yml generated-config-files/030-getmmodes-peeled-even.yml \
		.pipeline/001-peeled-transposed-data \
		.pipeline/002-flagged-peeled-data \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/030-m-modes-interpolated-peeled-even: \
		$(LIB)/030-getmmodes.jl project.yml generated-config-files/030-getmmodes-interpolated-peeled-even.yml \
		.pipeline/001-peeled-transposed-data \
		.pipeline/002-flagged-peeled-data \
		.pipeline/032-predicted-visibilities-peeled \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-peeled-even: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-peeled-even.yml \
		.pipeline/030-m-modes-peeled-even \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-peeled-even: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-channels-peeled-even.yml \
		.pipeline/030-m-modes-peeled-even \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-interpolated-peeled-even: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-interpolated-peeled-even.yml \
		.pipeline/030-m-modes-interpolated-peeled-even \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-interpolated-peeled-even: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-channels-interpolated-peeled-even.yml \
		.pipeline/030-m-modes-interpolated-peeled-even \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/101-averaged-m-modes-peeled-even: \
		$(LIB)/101-average-channels.jl project.yml generated-config-files/101-average-channels-m-modes-peeled-even.yml \
		.pipeline/030-m-modes-interpolated-peeled-even
	$(call launch-remote,1)

.pipeline/103-full-rank-compression-peeled-even: \
		$(LIB)/103-full-rank-compress.jl project.yml generated-config-files/103-full-rank-compress-peeled-even.yml \
		.pipeline/101-averaged-m-modes-peeled-even \
		.pipeline/101-averaged-transfer-matrix \
		.pipeline/102-noise-covariance-matrix-even
	$(call launch-remote,1)

.pipeline/112-foreground-filter-peeled-even-extreme: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-peeled-even-extreme.yml \
		.pipeline/103-full-rank-compression-peeled-even \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-peeled-even-extreme: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-peeled-even-extreme.yml \
		.pipeline/112-foreground-filter-peeled-even-extreme
	$(call launch-remote,1)

.pipeline/121-fisher-matrix-even-extreme-spherical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-even-extreme-spherical.yml \
		.pipeline/112-foreground-filter-peeled-even-extreme \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,4)

.pipeline/122-quadratic-estimator-peeled-even-extreme-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-even-extreme-spherical.yml \
		.pipeline/112-foreground-filter-peeled-even-extreme \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-even-extreme-spherical
	$(launch)

.pipeline/121-fisher-matrix-even-extreme-cylindrical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-even-extreme-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-even-extreme \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,4)

.pipeline/122-quadratic-estimator-peeled-even-extreme-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-even-extreme-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-even-extreme \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-even-extreme-cylindrical
	$(launch)

.pipeline/112-foreground-filter-peeled-even-moderate: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-peeled-even-moderate.yml \
		.pipeline/103-full-rank-compression-peeled-even \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-peeled-even-moderate: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-peeled-even-moderate.yml \
		.pipeline/112-foreground-filter-peeled-even-moderate
	$(call launch-remote,1)

.pipeline/121-fisher-matrix-even-moderate-spherical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-even-moderate-spherical.yml \
		.pipeline/112-foreground-filter-peeled-even-moderate \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,4)

.pipeline/122-quadratic-estimator-peeled-even-moderate-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-even-moderate-spherical.yml \
		.pipeline/112-foreground-filter-peeled-even-moderate \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-even-moderate-spherical
	$(launch)

.pipeline/121-fisher-matrix-even-moderate-cylindrical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-even-moderate-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-even-moderate \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,4)

.pipeline/122-quadratic-estimator-peeled-even-moderate-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-even-moderate-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-even-moderate \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-even-moderate-cylindrical
	$(launch)

.pipeline/112-foreground-filter-peeled-even-mild: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-peeled-even-mild.yml \
		.pipeline/103-full-rank-compression-peeled-even \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-peeled-even-mild: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-peeled-even-mild.yml \
		.pipeline/112-foreground-filter-peeled-even-mild
	$(call launch-remote,1)

.pipeline/121-fisher-matrix-even-mild-spherical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-even-mild-spherical.yml \
		.pipeline/112-foreground-filter-peeled-even-mild \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,2)

.pipeline/122-quadratic-estimator-peeled-even-mild-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-even-mild-spherical.yml \
		.pipeline/112-foreground-filter-peeled-even-mild \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-even-mild-spherical
	$(launch)

.pipeline/121-fisher-matrix-even-mild-cylindrical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-even-mild-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-even-mild \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,2)

.pipeline/122-quadratic-estimator-peeled-even-mild-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-even-mild-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-even-mild \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-even-mild-cylindrical
	$(launch)

.pipeline/112-foreground-filter-peeled-even-none: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-peeled-even-none.yml \
		.pipeline/103-full-rank-compression-peeled-even \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-peeled-even-none: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-peeled-even-none.yml \
		.pipeline/112-foreground-filter-peeled-even-none
	$(call launch-remote,1)

.pipeline/121-fisher-matrix-even-none-spherical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-even-none-spherical.yml \
		.pipeline/112-foreground-filter-peeled-even-none \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-peeled-even-none-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-even-none-spherical.yml \
		.pipeline/112-foreground-filter-peeled-even-none \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-even-none-spherical
	$(launch)

.pipeline/121-fisher-matrix-even-none-cylindrical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-even-none-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-even-none \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-peeled-even-none-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-even-none-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-even-none \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-even-none-cylindrical
	$(launch)

.pipeline/030-m-modes-peeled-day: \
		$(LIB)/030-getmmodes.jl project.yml generated-config-files/030-getmmodes-peeled-day.yml \
		.pipeline/001-peeled-transposed-data \
		.pipeline/002-flagged-peeled-data \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/030-m-modes-interpolated-peeled-day: \
		$(LIB)/030-getmmodes.jl project.yml generated-config-files/030-getmmodes-interpolated-peeled-day.yml \
		.pipeline/001-peeled-transposed-data \
		.pipeline/002-flagged-peeled-data \
		.pipeline/032-predicted-visibilities-peeled \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-peeled-day: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-peeled-day.yml \
		.pipeline/030-m-modes-peeled-day \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-peeled-day: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-channels-peeled-day.yml \
		.pipeline/030-m-modes-peeled-day \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-interpolated-peeled-day: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-interpolated-peeled-day.yml \
		.pipeline/030-m-modes-interpolated-peeled-day \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-interpolated-peeled-day: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-channels-interpolated-peeled-day.yml \
		.pipeline/030-m-modes-interpolated-peeled-day \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/101-averaged-m-modes-peeled-day: \
		$(LIB)/101-average-channels.jl project.yml generated-config-files/101-average-channels-m-modes-peeled-day.yml \
		.pipeline/030-m-modes-interpolated-peeled-day
	$(call launch-remote,1)

.pipeline/103-full-rank-compression-peeled-day: \
		$(LIB)/103-full-rank-compress.jl project.yml generated-config-files/103-full-rank-compress-peeled-day.yml \
		.pipeline/101-averaged-m-modes-peeled-day \
		.pipeline/101-averaged-transfer-matrix \
		.pipeline/102-noise-covariance-matrix-day
	$(call launch-remote,1)

.pipeline/112-foreground-filter-peeled-day-extreme: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-peeled-day-extreme.yml \
		.pipeline/103-full-rank-compression-peeled-day \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-peeled-day-extreme: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-peeled-day-extreme.yml \
		.pipeline/112-foreground-filter-peeled-day-extreme
	$(call launch-remote,1)

.pipeline/121-fisher-matrix-day-extreme-spherical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-day-extreme-spherical.yml \
		.pipeline/112-foreground-filter-peeled-day-extreme \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,4)

.pipeline/122-quadratic-estimator-peeled-day-extreme-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-day-extreme-spherical.yml \
		.pipeline/112-foreground-filter-peeled-day-extreme \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-day-extreme-spherical
	$(launch)

.pipeline/121-fisher-matrix-day-extreme-cylindrical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-day-extreme-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-day-extreme \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,4)

.pipeline/122-quadratic-estimator-peeled-day-extreme-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-day-extreme-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-day-extreme \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-day-extreme-cylindrical
	$(launch)

.pipeline/112-foreground-filter-peeled-day-moderate: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-peeled-day-moderate.yml \
		.pipeline/103-full-rank-compression-peeled-day \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-peeled-day-moderate: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-peeled-day-moderate.yml \
		.pipeline/112-foreground-filter-peeled-day-moderate
	$(call launch-remote,1)

.pipeline/121-fisher-matrix-day-moderate-spherical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-day-moderate-spherical.yml \
		.pipeline/112-foreground-filter-peeled-day-moderate \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,4)

.pipeline/122-quadratic-estimator-peeled-day-moderate-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-day-moderate-spherical.yml \
		.pipeline/112-foreground-filter-peeled-day-moderate \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-day-moderate-spherical
	$(launch)

.pipeline/121-fisher-matrix-day-moderate-cylindrical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-day-moderate-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-day-moderate \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,4)

.pipeline/122-quadratic-estimator-peeled-day-moderate-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-day-moderate-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-day-moderate \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-day-moderate-cylindrical
	$(launch)

.pipeline/112-foreground-filter-peeled-day-mild: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-peeled-day-mild.yml \
		.pipeline/103-full-rank-compression-peeled-day \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-peeled-day-mild: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-peeled-day-mild.yml \
		.pipeline/112-foreground-filter-peeled-day-mild
	$(call launch-remote,1)

.pipeline/121-fisher-matrix-day-mild-spherical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-day-mild-spherical.yml \
		.pipeline/112-foreground-filter-peeled-day-mild \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,2)

.pipeline/122-quadratic-estimator-peeled-day-mild-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-day-mild-spherical.yml \
		.pipeline/112-foreground-filter-peeled-day-mild \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-day-mild-spherical
	$(launch)

.pipeline/121-fisher-matrix-day-mild-cylindrical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-day-mild-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-day-mild \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,2)

.pipeline/122-quadratic-estimator-peeled-day-mild-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-day-mild-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-day-mild \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-day-mild-cylindrical
	$(launch)

.pipeline/112-foreground-filter-peeled-day-none: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-peeled-day-none.yml \
		.pipeline/103-full-rank-compression-peeled-day \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-peeled-day-none: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-peeled-day-none.yml \
		.pipeline/112-foreground-filter-peeled-day-none
	$(call launch-remote,1)

.pipeline/121-fisher-matrix-day-none-spherical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-day-none-spherical.yml \
		.pipeline/112-foreground-filter-peeled-day-none \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-peeled-day-none-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-day-none-spherical.yml \
		.pipeline/112-foreground-filter-peeled-day-none \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-day-none-spherical
	$(launch)

.pipeline/121-fisher-matrix-day-none-cylindrical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-day-none-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-day-none \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-peeled-day-none-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-day-none-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-day-none \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-day-none-cylindrical
	$(launch)

.pipeline/030-m-modes-peeled-night: \
		$(LIB)/030-getmmodes.jl project.yml generated-config-files/030-getmmodes-peeled-night.yml \
		.pipeline/001-peeled-transposed-data \
		.pipeline/002-flagged-peeled-data \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/030-m-modes-interpolated-peeled-night: \
		$(LIB)/030-getmmodes.jl project.yml generated-config-files/030-getmmodes-interpolated-peeled-night.yml \
		.pipeline/001-peeled-transposed-data \
		.pipeline/002-flagged-peeled-data \
		.pipeline/032-predicted-visibilities-peeled \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-peeled-night: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-peeled-night.yml \
		.pipeline/030-m-modes-peeled-night \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-peeled-night: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-channels-peeled-night.yml \
		.pipeline/030-m-modes-peeled-night \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-interpolated-peeled-night: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-interpolated-peeled-night.yml \
		.pipeline/030-m-modes-interpolated-peeled-night \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-interpolated-peeled-night: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-channels-interpolated-peeled-night.yml \
		.pipeline/030-m-modes-interpolated-peeled-night \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/101-averaged-m-modes-peeled-night: \
		$(LIB)/101-average-channels.jl project.yml generated-config-files/101-average-channels-m-modes-peeled-night.yml \
		.pipeline/030-m-modes-interpolated-peeled-night
	$(call launch-remote,1)

.pipeline/103-full-rank-compression-peeled-night: \
		$(LIB)/103-full-rank-compress.jl project.yml generated-config-files/103-full-rank-compress-peeled-night.yml \
		.pipeline/101-averaged-m-modes-peeled-night \
		.pipeline/101-averaged-transfer-matrix \
		.pipeline/102-noise-covariance-matrix-night
	$(call launch-remote,1)

.pipeline/112-foreground-filter-peeled-night-extreme: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-peeled-night-extreme.yml \
		.pipeline/103-full-rank-compression-peeled-night \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-peeled-night-extreme: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-peeled-night-extreme.yml \
		.pipeline/112-foreground-filter-peeled-night-extreme
	$(call launch-remote,1)

.pipeline/121-fisher-matrix-night-extreme-spherical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-night-extreme-spherical.yml \
		.pipeline/112-foreground-filter-peeled-night-extreme \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,4)

.pipeline/122-quadratic-estimator-peeled-night-extreme-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-night-extreme-spherical.yml \
		.pipeline/112-foreground-filter-peeled-night-extreme \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-night-extreme-spherical
	$(launch)

.pipeline/121-fisher-matrix-night-extreme-cylindrical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-night-extreme-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-night-extreme \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,4)

.pipeline/122-quadratic-estimator-peeled-night-extreme-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-night-extreme-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-night-extreme \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-night-extreme-cylindrical
	$(launch)

.pipeline/112-foreground-filter-peeled-night-moderate: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-peeled-night-moderate.yml \
		.pipeline/103-full-rank-compression-peeled-night \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-peeled-night-moderate: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-peeled-night-moderate.yml \
		.pipeline/112-foreground-filter-peeled-night-moderate
	$(call launch-remote,1)

.pipeline/121-fisher-matrix-night-moderate-spherical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-night-moderate-spherical.yml \
		.pipeline/112-foreground-filter-peeled-night-moderate \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,4)

.pipeline/122-quadratic-estimator-peeled-night-moderate-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-night-moderate-spherical.yml \
		.pipeline/112-foreground-filter-peeled-night-moderate \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-night-moderate-spherical
	$(launch)

.pipeline/121-fisher-matrix-night-moderate-cylindrical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-night-moderate-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-night-moderate \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,4)

.pipeline/122-quadratic-estimator-peeled-night-moderate-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-night-moderate-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-night-moderate \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-night-moderate-cylindrical
	$(launch)

.pipeline/112-foreground-filter-peeled-night-mild: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-peeled-night-mild.yml \
		.pipeline/103-full-rank-compression-peeled-night \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-peeled-night-mild: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-peeled-night-mild.yml \
		.pipeline/112-foreground-filter-peeled-night-mild
	$(call launch-remote,1)

.pipeline/121-fisher-matrix-night-mild-spherical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-night-mild-spherical.yml \
		.pipeline/112-foreground-filter-peeled-night-mild \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,2)

.pipeline/122-quadratic-estimator-peeled-night-mild-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-night-mild-spherical.yml \
		.pipeline/112-foreground-filter-peeled-night-mild \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-night-mild-spherical
	$(launch)

.pipeline/121-fisher-matrix-night-mild-cylindrical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-night-mild-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-night-mild \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,2)

.pipeline/122-quadratic-estimator-peeled-night-mild-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-night-mild-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-night-mild \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-night-mild-cylindrical
	$(launch)

.pipeline/112-foreground-filter-peeled-night-none: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-peeled-night-none.yml \
		.pipeline/103-full-rank-compression-peeled-night \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-peeled-night-none: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-peeled-night-none.yml \
		.pipeline/112-foreground-filter-peeled-night-none
	$(call launch-remote,1)

.pipeline/121-fisher-matrix-night-none-spherical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-night-none-spherical.yml \
		.pipeline/112-foreground-filter-peeled-night-none \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-peeled-night-none-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-night-none-spherical.yml \
		.pipeline/112-foreground-filter-peeled-night-none \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-night-none-spherical
	$(launch)

.pipeline/121-fisher-matrix-night-none-cylindrical: \
		$(LIB)/121-fisher-matrix.jl project.yml generated-config-files/121-fisher-matrix-night-none-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-night-none \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-peeled-night-none-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-peeled-night-none-cylindrical.yml \
		.pipeline/112-foreground-filter-peeled-night-none \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-night-none-cylindrical
	$(launch)

.pipeline/032-predicted-visibilities-peeled: \
		$(LIB)/032-predict-visibilities.jl project.yml generated-config-files/032-predict-visibilities-peeled.yml \
		.pipeline/031-dirty-map-peeled-all \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/101-averaged-m-modes-predicted-peeled: \
		$(LIB)/101-average-channels.jl project.yml generated-config-files/101-average-channels-m-modes-predicted-peeled.yml \
		.pipeline/032-predicted-visibilities-peeled
	$(call launch-remote,1)

.pipeline/103-full-rank-compression-predicted-peeled: \
		$(LIB)/103-full-rank-compress.jl project.yml generated-config-files/103-full-rank-compress-predicted-peeled.yml \
		.pipeline/101-averaged-m-modes-predicted-peeled \
		.pipeline/101-averaged-transfer-matrix \
		.pipeline/102-noise-covariance-matrix-all
	$(call launch-remote,1)

.pipeline/112-foreground-filter-predicted-peeled-extreme: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-predicted-peeled-extreme.yml \
		.pipeline/103-full-rank-compression-predicted-peeled \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/112-foreground-filter-predicted-peeled-moderate: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-predicted-peeled-moderate.yml \
		.pipeline/103-full-rank-compression-predicted-peeled \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/112-foreground-filter-predicted-peeled-mild: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-predicted-peeled-mild.yml \
		.pipeline/103-full-rank-compression-predicted-peeled \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/112-foreground-filter-predicted-peeled-none: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-predicted-peeled-none.yml \
		.pipeline/103-full-rank-compression-predicted-peeled \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/030-m-modes-recalibrated-all: \
		$(LIB)/030-getmmodes.jl project.yml generated-config-files/030-getmmodes-recalibrated-all.yml \
		.pipeline/001-recalibrated-transposed-data \
		.pipeline/002-flagged-peeled-data \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/030-m-modes-interpolated-recalibrated-all: \
		$(LIB)/030-getmmodes.jl project.yml generated-config-files/030-getmmodes-interpolated-recalibrated-all.yml \
		.pipeline/001-recalibrated-transposed-data \
		.pipeline/002-flagged-peeled-data \
		.pipeline/032-predicted-visibilities-recalibrated \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-recalibrated-all: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-recalibrated-all.yml \
		.pipeline/030-m-modes-recalibrated-all \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-recalibrated-all: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-channels-recalibrated-all.yml \
		.pipeline/030-m-modes-recalibrated-all \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-interpolated-recalibrated-all: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-interpolated-recalibrated-all.yml \
		.pipeline/030-m-modes-interpolated-recalibrated-all \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-interpolated-recalibrated-all: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-channels-interpolated-recalibrated-all.yml \
		.pipeline/030-m-modes-interpolated-recalibrated-all \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/101-averaged-m-modes-recalibrated-all: \
		$(LIB)/101-average-channels.jl project.yml generated-config-files/101-average-channels-m-modes-recalibrated-all.yml \
		.pipeline/030-m-modes-interpolated-recalibrated-all
	$(call launch-remote,1)

.pipeline/103-full-rank-compression-recalibrated-all: \
		$(LIB)/103-full-rank-compress.jl project.yml generated-config-files/103-full-rank-compress-recalibrated-all.yml \
		.pipeline/101-averaged-m-modes-recalibrated-all \
		.pipeline/101-averaged-transfer-matrix \
		.pipeline/102-noise-covariance-matrix-all
	$(call launch-remote,1)

.pipeline/112-foreground-filter-recalibrated-all-extreme: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-recalibrated-all-extreme.yml \
		.pipeline/103-full-rank-compression-recalibrated-all \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-recalibrated-all-extreme: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-recalibrated-all-extreme.yml \
		.pipeline/112-foreground-filter-recalibrated-all-extreme
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-recalibrated-all-extreme-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-all-extreme-spherical.yml \
		.pipeline/112-foreground-filter-recalibrated-all-extreme \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-all-extreme-spherical
	$(launch)

.pipeline/122-quadratic-estimator-recalibrated-all-extreme-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-all-extreme-cylindrical.yml \
		.pipeline/112-foreground-filter-recalibrated-all-extreme \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-all-extreme-cylindrical
	$(launch)

.pipeline/112-foreground-filter-recalibrated-all-moderate: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-recalibrated-all-moderate.yml \
		.pipeline/103-full-rank-compression-recalibrated-all \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-recalibrated-all-moderate: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-recalibrated-all-moderate.yml \
		.pipeline/112-foreground-filter-recalibrated-all-moderate
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-recalibrated-all-moderate-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-all-moderate-spherical.yml \
		.pipeline/112-foreground-filter-recalibrated-all-moderate \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-all-moderate-spherical
	$(launch)

.pipeline/122-quadratic-estimator-recalibrated-all-moderate-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-all-moderate-cylindrical.yml \
		.pipeline/112-foreground-filter-recalibrated-all-moderate \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-all-moderate-cylindrical
	$(launch)

.pipeline/112-foreground-filter-recalibrated-all-mild: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-recalibrated-all-mild.yml \
		.pipeline/103-full-rank-compression-recalibrated-all \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-recalibrated-all-mild: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-recalibrated-all-mild.yml \
		.pipeline/112-foreground-filter-recalibrated-all-mild
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-recalibrated-all-mild-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-all-mild-spherical.yml \
		.pipeline/112-foreground-filter-recalibrated-all-mild \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-all-mild-spherical
	$(launch)

.pipeline/122-quadratic-estimator-recalibrated-all-mild-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-all-mild-cylindrical.yml \
		.pipeline/112-foreground-filter-recalibrated-all-mild \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-all-mild-cylindrical
	$(launch)

.pipeline/112-foreground-filter-recalibrated-all-none: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-recalibrated-all-none.yml \
		.pipeline/103-full-rank-compression-recalibrated-all \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-recalibrated-all-none: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-recalibrated-all-none.yml \
		.pipeline/112-foreground-filter-recalibrated-all-none
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-recalibrated-all-none-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-all-none-spherical.yml \
		.pipeline/112-foreground-filter-recalibrated-all-none \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-all-none-spherical
	$(launch)

.pipeline/122-quadratic-estimator-recalibrated-all-none-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-all-none-cylindrical.yml \
		.pipeline/112-foreground-filter-recalibrated-all-none \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-all-none-cylindrical
	$(launch)

.pipeline/030-m-modes-recalibrated-odd: \
		$(LIB)/030-getmmodes.jl project.yml generated-config-files/030-getmmodes-recalibrated-odd.yml \
		.pipeline/001-recalibrated-transposed-data \
		.pipeline/002-flagged-peeled-data \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/030-m-modes-interpolated-recalibrated-odd: \
		$(LIB)/030-getmmodes.jl project.yml generated-config-files/030-getmmodes-interpolated-recalibrated-odd.yml \
		.pipeline/001-recalibrated-transposed-data \
		.pipeline/002-flagged-peeled-data \
		.pipeline/032-predicted-visibilities-recalibrated \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-recalibrated-odd: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-recalibrated-odd.yml \
		.pipeline/030-m-modes-recalibrated-odd \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-recalibrated-odd: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-channels-recalibrated-odd.yml \
		.pipeline/030-m-modes-recalibrated-odd \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-interpolated-recalibrated-odd: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-interpolated-recalibrated-odd.yml \
		.pipeline/030-m-modes-interpolated-recalibrated-odd \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-interpolated-recalibrated-odd: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-channels-interpolated-recalibrated-odd.yml \
		.pipeline/030-m-modes-interpolated-recalibrated-odd \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/101-averaged-m-modes-recalibrated-odd: \
		$(LIB)/101-average-channels.jl project.yml generated-config-files/101-average-channels-m-modes-recalibrated-odd.yml \
		.pipeline/030-m-modes-interpolated-recalibrated-odd
	$(call launch-remote,1)

.pipeline/103-full-rank-compression-recalibrated-odd: \
		$(LIB)/103-full-rank-compress.jl project.yml generated-config-files/103-full-rank-compress-recalibrated-odd.yml \
		.pipeline/101-averaged-m-modes-recalibrated-odd \
		.pipeline/101-averaged-transfer-matrix \
		.pipeline/102-noise-covariance-matrix-odd
	$(call launch-remote,1)

.pipeline/112-foreground-filter-recalibrated-odd-extreme: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-recalibrated-odd-extreme.yml \
		.pipeline/103-full-rank-compression-recalibrated-odd \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-recalibrated-odd-extreme: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-recalibrated-odd-extreme.yml \
		.pipeline/112-foreground-filter-recalibrated-odd-extreme
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-recalibrated-odd-extreme-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-odd-extreme-spherical.yml \
		.pipeline/112-foreground-filter-recalibrated-odd-extreme \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-odd-extreme-spherical
	$(launch)

.pipeline/122-quadratic-estimator-recalibrated-odd-extreme-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-odd-extreme-cylindrical.yml \
		.pipeline/112-foreground-filter-recalibrated-odd-extreme \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-odd-extreme-cylindrical
	$(launch)

.pipeline/112-foreground-filter-recalibrated-odd-moderate: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-recalibrated-odd-moderate.yml \
		.pipeline/103-full-rank-compression-recalibrated-odd \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-recalibrated-odd-moderate: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-recalibrated-odd-moderate.yml \
		.pipeline/112-foreground-filter-recalibrated-odd-moderate
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-recalibrated-odd-moderate-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-odd-moderate-spherical.yml \
		.pipeline/112-foreground-filter-recalibrated-odd-moderate \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-odd-moderate-spherical
	$(launch)

.pipeline/122-quadratic-estimator-recalibrated-odd-moderate-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-odd-moderate-cylindrical.yml \
		.pipeline/112-foreground-filter-recalibrated-odd-moderate \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-odd-moderate-cylindrical
	$(launch)

.pipeline/112-foreground-filter-recalibrated-odd-mild: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-recalibrated-odd-mild.yml \
		.pipeline/103-full-rank-compression-recalibrated-odd \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-recalibrated-odd-mild: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-recalibrated-odd-mild.yml \
		.pipeline/112-foreground-filter-recalibrated-odd-mild
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-recalibrated-odd-mild-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-odd-mild-spherical.yml \
		.pipeline/112-foreground-filter-recalibrated-odd-mild \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-odd-mild-spherical
	$(launch)

.pipeline/122-quadratic-estimator-recalibrated-odd-mild-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-odd-mild-cylindrical.yml \
		.pipeline/112-foreground-filter-recalibrated-odd-mild \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-odd-mild-cylindrical
	$(launch)

.pipeline/112-foreground-filter-recalibrated-odd-none: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-recalibrated-odd-none.yml \
		.pipeline/103-full-rank-compression-recalibrated-odd \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-recalibrated-odd-none: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-recalibrated-odd-none.yml \
		.pipeline/112-foreground-filter-recalibrated-odd-none
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-recalibrated-odd-none-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-odd-none-spherical.yml \
		.pipeline/112-foreground-filter-recalibrated-odd-none \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-odd-none-spherical
	$(launch)

.pipeline/122-quadratic-estimator-recalibrated-odd-none-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-odd-none-cylindrical.yml \
		.pipeline/112-foreground-filter-recalibrated-odd-none \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-odd-none-cylindrical
	$(launch)

.pipeline/030-m-modes-recalibrated-even: \
		$(LIB)/030-getmmodes.jl project.yml generated-config-files/030-getmmodes-recalibrated-even.yml \
		.pipeline/001-recalibrated-transposed-data \
		.pipeline/002-flagged-peeled-data \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/030-m-modes-interpolated-recalibrated-even: \
		$(LIB)/030-getmmodes.jl project.yml generated-config-files/030-getmmodes-interpolated-recalibrated-even.yml \
		.pipeline/001-recalibrated-transposed-data \
		.pipeline/002-flagged-peeled-data \
		.pipeline/032-predicted-visibilities-recalibrated \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-recalibrated-even: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-recalibrated-even.yml \
		.pipeline/030-m-modes-recalibrated-even \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-recalibrated-even: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-channels-recalibrated-even.yml \
		.pipeline/030-m-modes-recalibrated-even \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-interpolated-recalibrated-even: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-interpolated-recalibrated-even.yml \
		.pipeline/030-m-modes-interpolated-recalibrated-even \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-interpolated-recalibrated-even: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-channels-interpolated-recalibrated-even.yml \
		.pipeline/030-m-modes-interpolated-recalibrated-even \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/101-averaged-m-modes-recalibrated-even: \
		$(LIB)/101-average-channels.jl project.yml generated-config-files/101-average-channels-m-modes-recalibrated-even.yml \
		.pipeline/030-m-modes-interpolated-recalibrated-even
	$(call launch-remote,1)

.pipeline/103-full-rank-compression-recalibrated-even: \
		$(LIB)/103-full-rank-compress.jl project.yml generated-config-files/103-full-rank-compress-recalibrated-even.yml \
		.pipeline/101-averaged-m-modes-recalibrated-even \
		.pipeline/101-averaged-transfer-matrix \
		.pipeline/102-noise-covariance-matrix-even
	$(call launch-remote,1)

.pipeline/112-foreground-filter-recalibrated-even-extreme: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-recalibrated-even-extreme.yml \
		.pipeline/103-full-rank-compression-recalibrated-even \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-recalibrated-even-extreme: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-recalibrated-even-extreme.yml \
		.pipeline/112-foreground-filter-recalibrated-even-extreme
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-recalibrated-even-extreme-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-even-extreme-spherical.yml \
		.pipeline/112-foreground-filter-recalibrated-even-extreme \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-even-extreme-spherical
	$(launch)

.pipeline/122-quadratic-estimator-recalibrated-even-extreme-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-even-extreme-cylindrical.yml \
		.pipeline/112-foreground-filter-recalibrated-even-extreme \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-even-extreme-cylindrical
	$(launch)

.pipeline/112-foreground-filter-recalibrated-even-moderate: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-recalibrated-even-moderate.yml \
		.pipeline/103-full-rank-compression-recalibrated-even \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-recalibrated-even-moderate: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-recalibrated-even-moderate.yml \
		.pipeline/112-foreground-filter-recalibrated-even-moderate
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-recalibrated-even-moderate-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-even-moderate-spherical.yml \
		.pipeline/112-foreground-filter-recalibrated-even-moderate \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-even-moderate-spherical
	$(launch)

.pipeline/122-quadratic-estimator-recalibrated-even-moderate-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-even-moderate-cylindrical.yml \
		.pipeline/112-foreground-filter-recalibrated-even-moderate \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-even-moderate-cylindrical
	$(launch)

.pipeline/112-foreground-filter-recalibrated-even-mild: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-recalibrated-even-mild.yml \
		.pipeline/103-full-rank-compression-recalibrated-even \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-recalibrated-even-mild: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-recalibrated-even-mild.yml \
		.pipeline/112-foreground-filter-recalibrated-even-mild
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-recalibrated-even-mild-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-even-mild-spherical.yml \
		.pipeline/112-foreground-filter-recalibrated-even-mild \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-even-mild-spherical
	$(launch)

.pipeline/122-quadratic-estimator-recalibrated-even-mild-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-even-mild-cylindrical.yml \
		.pipeline/112-foreground-filter-recalibrated-even-mild \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-even-mild-cylindrical
	$(launch)

.pipeline/112-foreground-filter-recalibrated-even-none: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-recalibrated-even-none.yml \
		.pipeline/103-full-rank-compression-recalibrated-even \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-recalibrated-even-none: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-recalibrated-even-none.yml \
		.pipeline/112-foreground-filter-recalibrated-even-none
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-recalibrated-even-none-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-even-none-spherical.yml \
		.pipeline/112-foreground-filter-recalibrated-even-none \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-even-none-spherical
	$(launch)

.pipeline/122-quadratic-estimator-recalibrated-even-none-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-even-none-cylindrical.yml \
		.pipeline/112-foreground-filter-recalibrated-even-none \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-even-none-cylindrical
	$(launch)

.pipeline/030-m-modes-recalibrated-day: \
		$(LIB)/030-getmmodes.jl project.yml generated-config-files/030-getmmodes-recalibrated-day.yml \
		.pipeline/001-recalibrated-transposed-data \
		.pipeline/002-flagged-peeled-data \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/030-m-modes-interpolated-recalibrated-day: \
		$(LIB)/030-getmmodes.jl project.yml generated-config-files/030-getmmodes-interpolated-recalibrated-day.yml \
		.pipeline/001-recalibrated-transposed-data \
		.pipeline/002-flagged-peeled-data \
		.pipeline/032-predicted-visibilities-recalibrated \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-recalibrated-day: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-recalibrated-day.yml \
		.pipeline/030-m-modes-recalibrated-day \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-recalibrated-day: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-channels-recalibrated-day.yml \
		.pipeline/030-m-modes-recalibrated-day \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-interpolated-recalibrated-day: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-interpolated-recalibrated-day.yml \
		.pipeline/030-m-modes-interpolated-recalibrated-day \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-interpolated-recalibrated-day: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-channels-interpolated-recalibrated-day.yml \
		.pipeline/030-m-modes-interpolated-recalibrated-day \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/101-averaged-m-modes-recalibrated-day: \
		$(LIB)/101-average-channels.jl project.yml generated-config-files/101-average-channels-m-modes-recalibrated-day.yml \
		.pipeline/030-m-modes-interpolated-recalibrated-day
	$(call launch-remote,1)

.pipeline/103-full-rank-compression-recalibrated-day: \
		$(LIB)/103-full-rank-compress.jl project.yml generated-config-files/103-full-rank-compress-recalibrated-day.yml \
		.pipeline/101-averaged-m-modes-recalibrated-day \
		.pipeline/101-averaged-transfer-matrix \
		.pipeline/102-noise-covariance-matrix-day
	$(call launch-remote,1)

.pipeline/112-foreground-filter-recalibrated-day-extreme: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-recalibrated-day-extreme.yml \
		.pipeline/103-full-rank-compression-recalibrated-day \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-recalibrated-day-extreme: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-recalibrated-day-extreme.yml \
		.pipeline/112-foreground-filter-recalibrated-day-extreme
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-recalibrated-day-extreme-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-day-extreme-spherical.yml \
		.pipeline/112-foreground-filter-recalibrated-day-extreme \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-day-extreme-spherical
	$(launch)

.pipeline/122-quadratic-estimator-recalibrated-day-extreme-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-day-extreme-cylindrical.yml \
		.pipeline/112-foreground-filter-recalibrated-day-extreme \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-day-extreme-cylindrical
	$(launch)

.pipeline/112-foreground-filter-recalibrated-day-moderate: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-recalibrated-day-moderate.yml \
		.pipeline/103-full-rank-compression-recalibrated-day \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-recalibrated-day-moderate: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-recalibrated-day-moderate.yml \
		.pipeline/112-foreground-filter-recalibrated-day-moderate
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-recalibrated-day-moderate-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-day-moderate-spherical.yml \
		.pipeline/112-foreground-filter-recalibrated-day-moderate \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-day-moderate-spherical
	$(launch)

.pipeline/122-quadratic-estimator-recalibrated-day-moderate-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-day-moderate-cylindrical.yml \
		.pipeline/112-foreground-filter-recalibrated-day-moderate \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-day-moderate-cylindrical
	$(launch)

.pipeline/112-foreground-filter-recalibrated-day-mild: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-recalibrated-day-mild.yml \
		.pipeline/103-full-rank-compression-recalibrated-day \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-recalibrated-day-mild: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-recalibrated-day-mild.yml \
		.pipeline/112-foreground-filter-recalibrated-day-mild
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-recalibrated-day-mild-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-day-mild-spherical.yml \
		.pipeline/112-foreground-filter-recalibrated-day-mild \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-day-mild-spherical
	$(launch)

.pipeline/122-quadratic-estimator-recalibrated-day-mild-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-day-mild-cylindrical.yml \
		.pipeline/112-foreground-filter-recalibrated-day-mild \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-day-mild-cylindrical
	$(launch)

.pipeline/112-foreground-filter-recalibrated-day-none: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-recalibrated-day-none.yml \
		.pipeline/103-full-rank-compression-recalibrated-day \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-recalibrated-day-none: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-recalibrated-day-none.yml \
		.pipeline/112-foreground-filter-recalibrated-day-none
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-recalibrated-day-none-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-day-none-spherical.yml \
		.pipeline/112-foreground-filter-recalibrated-day-none \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-day-none-spherical
	$(launch)

.pipeline/122-quadratic-estimator-recalibrated-day-none-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-day-none-cylindrical.yml \
		.pipeline/112-foreground-filter-recalibrated-day-none \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-day-none-cylindrical
	$(launch)

.pipeline/030-m-modes-recalibrated-night: \
		$(LIB)/030-getmmodes.jl project.yml generated-config-files/030-getmmodes-recalibrated-night.yml \
		.pipeline/001-recalibrated-transposed-data \
		.pipeline/002-flagged-peeled-data \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/030-m-modes-interpolated-recalibrated-night: \
		$(LIB)/030-getmmodes.jl project.yml generated-config-files/030-getmmodes-interpolated-recalibrated-night.yml \
		.pipeline/001-recalibrated-transposed-data \
		.pipeline/002-flagged-peeled-data \
		.pipeline/032-predicted-visibilities-recalibrated \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-recalibrated-night: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-recalibrated-night.yml \
		.pipeline/030-m-modes-recalibrated-night \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-recalibrated-night: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-channels-recalibrated-night.yml \
		.pipeline/030-m-modes-recalibrated-night \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-interpolated-recalibrated-night: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-interpolated-recalibrated-night.yml \
		.pipeline/030-m-modes-interpolated-recalibrated-night \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-interpolated-recalibrated-night: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-channels-interpolated-recalibrated-night.yml \
		.pipeline/030-m-modes-interpolated-recalibrated-night \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/101-averaged-m-modes-recalibrated-night: \
		$(LIB)/101-average-channels.jl project.yml generated-config-files/101-average-channels-m-modes-recalibrated-night.yml \
		.pipeline/030-m-modes-interpolated-recalibrated-night
	$(call launch-remote,1)

.pipeline/103-full-rank-compression-recalibrated-night: \
		$(LIB)/103-full-rank-compress.jl project.yml generated-config-files/103-full-rank-compress-recalibrated-night.yml \
		.pipeline/101-averaged-m-modes-recalibrated-night \
		.pipeline/101-averaged-transfer-matrix \
		.pipeline/102-noise-covariance-matrix-night
	$(call launch-remote,1)

.pipeline/112-foreground-filter-recalibrated-night-extreme: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-recalibrated-night-extreme.yml \
		.pipeline/103-full-rank-compression-recalibrated-night \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-recalibrated-night-extreme: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-recalibrated-night-extreme.yml \
		.pipeline/112-foreground-filter-recalibrated-night-extreme
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-recalibrated-night-extreme-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-night-extreme-spherical.yml \
		.pipeline/112-foreground-filter-recalibrated-night-extreme \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-night-extreme-spherical
	$(launch)

.pipeline/122-quadratic-estimator-recalibrated-night-extreme-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-night-extreme-cylindrical.yml \
		.pipeline/112-foreground-filter-recalibrated-night-extreme \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-night-extreme-cylindrical
	$(launch)

.pipeline/112-foreground-filter-recalibrated-night-moderate: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-recalibrated-night-moderate.yml \
		.pipeline/103-full-rank-compression-recalibrated-night \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-recalibrated-night-moderate: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-recalibrated-night-moderate.yml \
		.pipeline/112-foreground-filter-recalibrated-night-moderate
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-recalibrated-night-moderate-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-night-moderate-spherical.yml \
		.pipeline/112-foreground-filter-recalibrated-night-moderate \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-night-moderate-spherical
	$(launch)

.pipeline/122-quadratic-estimator-recalibrated-night-moderate-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-night-moderate-cylindrical.yml \
		.pipeline/112-foreground-filter-recalibrated-night-moderate \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-night-moderate-cylindrical
	$(launch)

.pipeline/112-foreground-filter-recalibrated-night-mild: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-recalibrated-night-mild.yml \
		.pipeline/103-full-rank-compression-recalibrated-night \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-recalibrated-night-mild: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-recalibrated-night-mild.yml \
		.pipeline/112-foreground-filter-recalibrated-night-mild
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-recalibrated-night-mild-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-night-mild-spherical.yml \
		.pipeline/112-foreground-filter-recalibrated-night-mild \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-night-mild-spherical
	$(launch)

.pipeline/122-quadratic-estimator-recalibrated-night-mild-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-night-mild-cylindrical.yml \
		.pipeline/112-foreground-filter-recalibrated-night-mild \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-night-mild-cylindrical
	$(launch)

.pipeline/112-foreground-filter-recalibrated-night-none: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-recalibrated-night-none.yml \
		.pipeline/103-full-rank-compression-recalibrated-night \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/031-dirty-map-filtered-recalibrated-night-none: \
		$(LIB)/031-tikhonov.jl project.yml generated-config-files/031-tikhonov-filtered-recalibrated-night-none.yml \
		.pipeline/112-foreground-filter-recalibrated-night-none
	$(call launch-remote,1)

.pipeline/122-quadratic-estimator-recalibrated-night-none-spherical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-night-none-spherical.yml \
		.pipeline/112-foreground-filter-recalibrated-night-none \
		.pipeline/120-basis-covariance-matrices-spherical \
		.pipeline/121-fisher-matrix-night-none-spherical
	$(launch)

.pipeline/122-quadratic-estimator-recalibrated-night-none-cylindrical: \
		$(LIB)/122-quadratic-estimator.jl project.yml generated-config-files/122-quadratic-estimator-recalibrated-night-none-cylindrical.yml \
		.pipeline/112-foreground-filter-recalibrated-night-none \
		.pipeline/120-basis-covariance-matrices-cylindrical \
		.pipeline/121-fisher-matrix-night-none-cylindrical
	$(launch)

.pipeline/032-predicted-visibilities-recalibrated: \
		$(LIB)/032-predict-visibilities.jl project.yml generated-config-files/032-predict-visibilities-recalibrated.yml \
		.pipeline/031-dirty-map-recalibrated-all \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/101-averaged-m-modes-predicted-recalibrated: \
		$(LIB)/101-average-channels.jl project.yml generated-config-files/101-average-channels-m-modes-predicted-recalibrated.yml \
		.pipeline/032-predicted-visibilities-recalibrated
	$(call launch-remote,1)

.pipeline/103-full-rank-compression-predicted-recalibrated: \
		$(LIB)/103-full-rank-compress.jl project.yml generated-config-files/103-full-rank-compress-predicted-recalibrated.yml \
		.pipeline/101-averaged-m-modes-predicted-recalibrated \
		.pipeline/101-averaged-transfer-matrix \
		.pipeline/102-noise-covariance-matrix-all
	$(call launch-remote,1)

.pipeline/112-foreground-filter-predicted-recalibrated-extreme: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-predicted-recalibrated-extreme.yml \
		.pipeline/103-full-rank-compression-predicted-recalibrated \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/112-foreground-filter-predicted-recalibrated-moderate: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-predicted-recalibrated-moderate.yml \
		.pipeline/103-full-rank-compression-predicted-recalibrated \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/112-foreground-filter-predicted-recalibrated-mild: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-predicted-recalibrated-mild.yml \
		.pipeline/103-full-rank-compression-predicted-recalibrated \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/112-foreground-filter-predicted-recalibrated-none: \
		$(LIB)/112-foreground-filter.jl project.yml generated-config-files/112-foreground-filter-predicted-recalibrated-none.yml \
		.pipeline/103-full-rank-compression-predicted-recalibrated \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

