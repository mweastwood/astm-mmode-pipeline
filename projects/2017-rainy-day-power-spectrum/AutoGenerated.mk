# This file was auto-generated. Do not edit directly!
.pipeline/030-m-modes-calibrated-all: \
		$(LIB)/030-getmmodes.jl project.yml 030-getmmodes-calibrated-all.yml \
		.pipeline/001-calibrated-transposed-data \
		.pipeline/002-flagged-calibrated-data \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/030-m-modes-interpolated-calibrated-all: \
		$(LIB)/030-getmmodes.jl project.yml 030-getmmodes-interpolated-calibrated-all.yml \
		.pipeline/001-calibrated-transposed-data \
		.pipeline/002-flagged-calibrated-data \
		.pipeline/032-predicted-visibilities-calibrated \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-calibrated-all: \
		$(LIB)/031-tikhonov.jl project.yml 031-tikhonov-calibrated-all.yml \
		.pipeline/030-m-modes-calibrated-all \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-calibrated-all: \
		$(LIB)/031-tikhonov.jl project.yml 031-tikhonov-channels-calibrated-all.yml \
		.pipeline/030-m-modes-calibrated-all \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-interpolated-calibrated-all: \
		$(LIB)/031-tikhonov.jl project.yml 031-tikhonov-interpolated-calibrated-all.yml \
		.pipeline/030-m-modes-interpolated-calibrated-all \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-interpolated-calibrated-all: \
		$(LIB)/031-tikhonov.jl project.yml 031-tikhonov-channels-interpolated-calibrated-all.yml \
		.pipeline/030-m-modes-interpolated-calibrated-all \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/101-averaged-m-modes-calibrated-all: \
		$(LIB)/101-average-channels.jl project.yml 101-average-channels-m-modes-calibrated-all.yml \
		.pipeline/030-m-modes-interpolated-calibrated-all
	$(call launch-remote,1)

.pipeline/103-full-rank-compression-calibrated-all: \
		$(LIB)/103-full-rank-compress.jl project.yml 103-full-rank-compress-calibrated-all.yml \
		.pipeline/101-averaged-m-modes-calibrated-all \
		.pipeline/101-averaged-transfer-matrix \
		.pipeline/102-noise-covariance-matrix-all
	$(call launch-remote,1)

.pipeline/112-foreground-filter-calibrated-all-extreme: \
		$(LIB)/112-foreground-filter.jl project.yml 112-foreground-filter-calibrated-all-extreme.yml \
		.pipeline/103-full-rank-compression-calibrated-all \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/121-quadratic-estimator-calibrated-all-extreme-spherical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-calibrated-all-extreme-spherical.yml \
	    .pipeline/112-foreground-filter-calibrated-all-extreme \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-calibrated-all-extreme-cylindrical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-calibrated-all-extreme-cylindrical.yml \
	    .pipeline/112-foreground-filter-calibrated-all-extreme \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-calibrated-all-extreme-angular: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-calibrated-all-extreme-angular.yml \
	    .pipeline/112-foreground-filter-calibrated-all-extreme \
		.pipeline/120-basis-covariance-matrices-angular
	$(call launch-remote,4)

.pipeline/112-foreground-filter-calibrated-all-moderate: \
		$(LIB)/112-foreground-filter.jl project.yml 112-foreground-filter-calibrated-all-moderate.yml \
		.pipeline/103-full-rank-compression-calibrated-all \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/121-quadratic-estimator-calibrated-all-moderate-spherical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-calibrated-all-moderate-spherical.yml \
	    .pipeline/112-foreground-filter-calibrated-all-moderate \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-calibrated-all-moderate-cylindrical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-calibrated-all-moderate-cylindrical.yml \
	    .pipeline/112-foreground-filter-calibrated-all-moderate \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-calibrated-all-moderate-angular: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-calibrated-all-moderate-angular.yml \
	    .pipeline/112-foreground-filter-calibrated-all-moderate \
		.pipeline/120-basis-covariance-matrices-angular
	$(call launch-remote,4)

.pipeline/112-foreground-filter-calibrated-all-mild: \
		$(LIB)/112-foreground-filter.jl project.yml 112-foreground-filter-calibrated-all-mild.yml \
		.pipeline/103-full-rank-compression-calibrated-all \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/121-quadratic-estimator-calibrated-all-mild-spherical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-calibrated-all-mild-spherical.yml \
	    .pipeline/112-foreground-filter-calibrated-all-mild \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-calibrated-all-mild-cylindrical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-calibrated-all-mild-cylindrical.yml \
	    .pipeline/112-foreground-filter-calibrated-all-mild \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-calibrated-all-mild-angular: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-calibrated-all-mild-angular.yml \
	    .pipeline/112-foreground-filter-calibrated-all-mild \
		.pipeline/120-basis-covariance-matrices-angular
	$(call launch-remote,4)

.pipeline/030-m-modes-calibrated-odd: \
		$(LIB)/030-getmmodes.jl project.yml 030-getmmodes-calibrated-odd.yml \
		.pipeline/001-calibrated-transposed-data \
		.pipeline/002-flagged-calibrated-data \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/030-m-modes-interpolated-calibrated-odd: \
		$(LIB)/030-getmmodes.jl project.yml 030-getmmodes-interpolated-calibrated-odd.yml \
		.pipeline/001-calibrated-transposed-data \
		.pipeline/002-flagged-calibrated-data \
		.pipeline/032-predicted-visibilities-calibrated \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-calibrated-odd: \
		$(LIB)/031-tikhonov.jl project.yml 031-tikhonov-calibrated-odd.yml \
		.pipeline/030-m-modes-calibrated-odd \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-calibrated-odd: \
		$(LIB)/031-tikhonov.jl project.yml 031-tikhonov-channels-calibrated-odd.yml \
		.pipeline/030-m-modes-calibrated-odd \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-interpolated-calibrated-odd: \
		$(LIB)/031-tikhonov.jl project.yml 031-tikhonov-interpolated-calibrated-odd.yml \
		.pipeline/030-m-modes-interpolated-calibrated-odd \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-interpolated-calibrated-odd: \
		$(LIB)/031-tikhonov.jl project.yml 031-tikhonov-channels-interpolated-calibrated-odd.yml \
		.pipeline/030-m-modes-interpolated-calibrated-odd \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/101-averaged-m-modes-calibrated-odd: \
		$(LIB)/101-average-channels.jl project.yml 101-average-channels-m-modes-calibrated-odd.yml \
		.pipeline/030-m-modes-interpolated-calibrated-odd
	$(call launch-remote,1)

.pipeline/103-full-rank-compression-calibrated-odd: \
		$(LIB)/103-full-rank-compress.jl project.yml 103-full-rank-compress-calibrated-odd.yml \
		.pipeline/101-averaged-m-modes-calibrated-odd \
		.pipeline/101-averaged-transfer-matrix \
		.pipeline/102-noise-covariance-matrix-odd
	$(call launch-remote,1)

.pipeline/112-foreground-filter-calibrated-odd-extreme: \
		$(LIB)/112-foreground-filter.jl project.yml 112-foreground-filter-calibrated-odd-extreme.yml \
		.pipeline/103-full-rank-compression-calibrated-odd \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/121-quadratic-estimator-calibrated-odd-extreme-spherical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-calibrated-odd-extreme-spherical.yml \
	    .pipeline/112-foreground-filter-calibrated-odd-extreme \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-calibrated-odd-extreme-cylindrical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-calibrated-odd-extreme-cylindrical.yml \
	    .pipeline/112-foreground-filter-calibrated-odd-extreme \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-calibrated-odd-extreme-angular: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-calibrated-odd-extreme-angular.yml \
	    .pipeline/112-foreground-filter-calibrated-odd-extreme \
		.pipeline/120-basis-covariance-matrices-angular
	$(call launch-remote,4)

.pipeline/112-foreground-filter-calibrated-odd-moderate: \
		$(LIB)/112-foreground-filter.jl project.yml 112-foreground-filter-calibrated-odd-moderate.yml \
		.pipeline/103-full-rank-compression-calibrated-odd \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/121-quadratic-estimator-calibrated-odd-moderate-spherical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-calibrated-odd-moderate-spherical.yml \
	    .pipeline/112-foreground-filter-calibrated-odd-moderate \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-calibrated-odd-moderate-cylindrical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-calibrated-odd-moderate-cylindrical.yml \
	    .pipeline/112-foreground-filter-calibrated-odd-moderate \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-calibrated-odd-moderate-angular: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-calibrated-odd-moderate-angular.yml \
	    .pipeline/112-foreground-filter-calibrated-odd-moderate \
		.pipeline/120-basis-covariance-matrices-angular
	$(call launch-remote,4)

.pipeline/112-foreground-filter-calibrated-odd-mild: \
		$(LIB)/112-foreground-filter.jl project.yml 112-foreground-filter-calibrated-odd-mild.yml \
		.pipeline/103-full-rank-compression-calibrated-odd \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/121-quadratic-estimator-calibrated-odd-mild-spherical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-calibrated-odd-mild-spherical.yml \
	    .pipeline/112-foreground-filter-calibrated-odd-mild \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-calibrated-odd-mild-cylindrical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-calibrated-odd-mild-cylindrical.yml \
	    .pipeline/112-foreground-filter-calibrated-odd-mild \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-calibrated-odd-mild-angular: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-calibrated-odd-mild-angular.yml \
	    .pipeline/112-foreground-filter-calibrated-odd-mild \
		.pipeline/120-basis-covariance-matrices-angular
	$(call launch-remote,4)

.pipeline/030-m-modes-calibrated-even: \
		$(LIB)/030-getmmodes.jl project.yml 030-getmmodes-calibrated-even.yml \
		.pipeline/001-calibrated-transposed-data \
		.pipeline/002-flagged-calibrated-data \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/030-m-modes-interpolated-calibrated-even: \
		$(LIB)/030-getmmodes.jl project.yml 030-getmmodes-interpolated-calibrated-even.yml \
		.pipeline/001-calibrated-transposed-data \
		.pipeline/002-flagged-calibrated-data \
		.pipeline/032-predicted-visibilities-calibrated \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-calibrated-even: \
		$(LIB)/031-tikhonov.jl project.yml 031-tikhonov-calibrated-even.yml \
		.pipeline/030-m-modes-calibrated-even \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-calibrated-even: \
		$(LIB)/031-tikhonov.jl project.yml 031-tikhonov-channels-calibrated-even.yml \
		.pipeline/030-m-modes-calibrated-even \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-interpolated-calibrated-even: \
		$(LIB)/031-tikhonov.jl project.yml 031-tikhonov-interpolated-calibrated-even.yml \
		.pipeline/030-m-modes-interpolated-calibrated-even \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-interpolated-calibrated-even: \
		$(LIB)/031-tikhonov.jl project.yml 031-tikhonov-channels-interpolated-calibrated-even.yml \
		.pipeline/030-m-modes-interpolated-calibrated-even \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/101-averaged-m-modes-calibrated-even: \
		$(LIB)/101-average-channels.jl project.yml 101-average-channels-m-modes-calibrated-even.yml \
		.pipeline/030-m-modes-interpolated-calibrated-even
	$(call launch-remote,1)

.pipeline/103-full-rank-compression-calibrated-even: \
		$(LIB)/103-full-rank-compress.jl project.yml 103-full-rank-compress-calibrated-even.yml \
		.pipeline/101-averaged-m-modes-calibrated-even \
		.pipeline/101-averaged-transfer-matrix \
		.pipeline/102-noise-covariance-matrix-even
	$(call launch-remote,1)

.pipeline/112-foreground-filter-calibrated-even-extreme: \
		$(LIB)/112-foreground-filter.jl project.yml 112-foreground-filter-calibrated-even-extreme.yml \
		.pipeline/103-full-rank-compression-calibrated-even \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/121-quadratic-estimator-calibrated-even-extreme-spherical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-calibrated-even-extreme-spherical.yml \
	    .pipeline/112-foreground-filter-calibrated-even-extreme \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-calibrated-even-extreme-cylindrical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-calibrated-even-extreme-cylindrical.yml \
	    .pipeline/112-foreground-filter-calibrated-even-extreme \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-calibrated-even-extreme-angular: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-calibrated-even-extreme-angular.yml \
	    .pipeline/112-foreground-filter-calibrated-even-extreme \
		.pipeline/120-basis-covariance-matrices-angular
	$(call launch-remote,4)

.pipeline/112-foreground-filter-calibrated-even-moderate: \
		$(LIB)/112-foreground-filter.jl project.yml 112-foreground-filter-calibrated-even-moderate.yml \
		.pipeline/103-full-rank-compression-calibrated-even \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/121-quadratic-estimator-calibrated-even-moderate-spherical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-calibrated-even-moderate-spherical.yml \
	    .pipeline/112-foreground-filter-calibrated-even-moderate \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-calibrated-even-moderate-cylindrical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-calibrated-even-moderate-cylindrical.yml \
	    .pipeline/112-foreground-filter-calibrated-even-moderate \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-calibrated-even-moderate-angular: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-calibrated-even-moderate-angular.yml \
	    .pipeline/112-foreground-filter-calibrated-even-moderate \
		.pipeline/120-basis-covariance-matrices-angular
	$(call launch-remote,4)

.pipeline/112-foreground-filter-calibrated-even-mild: \
		$(LIB)/112-foreground-filter.jl project.yml 112-foreground-filter-calibrated-even-mild.yml \
		.pipeline/103-full-rank-compression-calibrated-even \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/121-quadratic-estimator-calibrated-even-mild-spherical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-calibrated-even-mild-spherical.yml \
	    .pipeline/112-foreground-filter-calibrated-even-mild \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-calibrated-even-mild-cylindrical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-calibrated-even-mild-cylindrical.yml \
	    .pipeline/112-foreground-filter-calibrated-even-mild \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-calibrated-even-mild-angular: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-calibrated-even-mild-angular.yml \
	    .pipeline/112-foreground-filter-calibrated-even-mild \
		.pipeline/120-basis-covariance-matrices-angular
	$(call launch-remote,4)

.pipeline/032-predicted-visibilities-calibrated: \
		$(LIB)/032-predict-visibilities.jl project.yml 032-predict-visibilities-calibrated.yml \
		.pipeline/031-dirty-map-calibrated-all \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/030-m-modes-peeled-all: \
		$(LIB)/030-getmmodes.jl project.yml 030-getmmodes-peeled-all.yml \
		.pipeline/001-peeled-transposed-data \
		.pipeline/002-flagged-peeled-data \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/030-m-modes-interpolated-peeled-all: \
		$(LIB)/030-getmmodes.jl project.yml 030-getmmodes-interpolated-peeled-all.yml \
		.pipeline/001-peeled-transposed-data \
		.pipeline/002-flagged-peeled-data \
		.pipeline/032-predicted-visibilities-peeled \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-peeled-all: \
		$(LIB)/031-tikhonov.jl project.yml 031-tikhonov-peeled-all.yml \
		.pipeline/030-m-modes-peeled-all \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-peeled-all: \
		$(LIB)/031-tikhonov.jl project.yml 031-tikhonov-channels-peeled-all.yml \
		.pipeline/030-m-modes-peeled-all \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-interpolated-peeled-all: \
		$(LIB)/031-tikhonov.jl project.yml 031-tikhonov-interpolated-peeled-all.yml \
		.pipeline/030-m-modes-interpolated-peeled-all \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-interpolated-peeled-all: \
		$(LIB)/031-tikhonov.jl project.yml 031-tikhonov-channels-interpolated-peeled-all.yml \
		.pipeline/030-m-modes-interpolated-peeled-all \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/101-averaged-m-modes-peeled-all: \
		$(LIB)/101-average-channels.jl project.yml 101-average-channels-m-modes-peeled-all.yml \
		.pipeline/030-m-modes-interpolated-peeled-all
	$(call launch-remote,1)

.pipeline/103-full-rank-compression-peeled-all: \
		$(LIB)/103-full-rank-compress.jl project.yml 103-full-rank-compress-peeled-all.yml \
		.pipeline/101-averaged-m-modes-peeled-all \
		.pipeline/101-averaged-transfer-matrix \
		.pipeline/102-noise-covariance-matrix-all
	$(call launch-remote,1)

.pipeline/112-foreground-filter-peeled-all-extreme: \
		$(LIB)/112-foreground-filter.jl project.yml 112-foreground-filter-peeled-all-extreme.yml \
		.pipeline/103-full-rank-compression-peeled-all \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/121-quadratic-estimator-peeled-all-extreme-spherical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-peeled-all-extreme-spherical.yml \
	    .pipeline/112-foreground-filter-peeled-all-extreme \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-peeled-all-extreme-cylindrical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-peeled-all-extreme-cylindrical.yml \
	    .pipeline/112-foreground-filter-peeled-all-extreme \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-peeled-all-extreme-angular: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-peeled-all-extreme-angular.yml \
	    .pipeline/112-foreground-filter-peeled-all-extreme \
		.pipeline/120-basis-covariance-matrices-angular
	$(call launch-remote,4)

.pipeline/112-foreground-filter-peeled-all-moderate: \
		$(LIB)/112-foreground-filter.jl project.yml 112-foreground-filter-peeled-all-moderate.yml \
		.pipeline/103-full-rank-compression-peeled-all \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/121-quadratic-estimator-peeled-all-moderate-spherical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-peeled-all-moderate-spherical.yml \
	    .pipeline/112-foreground-filter-peeled-all-moderate \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-peeled-all-moderate-cylindrical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-peeled-all-moderate-cylindrical.yml \
	    .pipeline/112-foreground-filter-peeled-all-moderate \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-peeled-all-moderate-angular: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-peeled-all-moderate-angular.yml \
	    .pipeline/112-foreground-filter-peeled-all-moderate \
		.pipeline/120-basis-covariance-matrices-angular
	$(call launch-remote,4)

.pipeline/112-foreground-filter-peeled-all-mild: \
		$(LIB)/112-foreground-filter.jl project.yml 112-foreground-filter-peeled-all-mild.yml \
		.pipeline/103-full-rank-compression-peeled-all \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/121-quadratic-estimator-peeled-all-mild-spherical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-peeled-all-mild-spherical.yml \
	    .pipeline/112-foreground-filter-peeled-all-mild \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-peeled-all-mild-cylindrical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-peeled-all-mild-cylindrical.yml \
	    .pipeline/112-foreground-filter-peeled-all-mild \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-peeled-all-mild-angular: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-peeled-all-mild-angular.yml \
	    .pipeline/112-foreground-filter-peeled-all-mild \
		.pipeline/120-basis-covariance-matrices-angular
	$(call launch-remote,4)

.pipeline/030-m-modes-peeled-odd: \
		$(LIB)/030-getmmodes.jl project.yml 030-getmmodes-peeled-odd.yml \
		.pipeline/001-peeled-transposed-data \
		.pipeline/002-flagged-peeled-data \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/030-m-modes-interpolated-peeled-odd: \
		$(LIB)/030-getmmodes.jl project.yml 030-getmmodes-interpolated-peeled-odd.yml \
		.pipeline/001-peeled-transposed-data \
		.pipeline/002-flagged-peeled-data \
		.pipeline/032-predicted-visibilities-peeled \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-peeled-odd: \
		$(LIB)/031-tikhonov.jl project.yml 031-tikhonov-peeled-odd.yml \
		.pipeline/030-m-modes-peeled-odd \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-peeled-odd: \
		$(LIB)/031-tikhonov.jl project.yml 031-tikhonov-channels-peeled-odd.yml \
		.pipeline/030-m-modes-peeled-odd \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-interpolated-peeled-odd: \
		$(LIB)/031-tikhonov.jl project.yml 031-tikhonov-interpolated-peeled-odd.yml \
		.pipeline/030-m-modes-interpolated-peeled-odd \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-interpolated-peeled-odd: \
		$(LIB)/031-tikhonov.jl project.yml 031-tikhonov-channels-interpolated-peeled-odd.yml \
		.pipeline/030-m-modes-interpolated-peeled-odd \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/101-averaged-m-modes-peeled-odd: \
		$(LIB)/101-average-channels.jl project.yml 101-average-channels-m-modes-peeled-odd.yml \
		.pipeline/030-m-modes-interpolated-peeled-odd
	$(call launch-remote,1)

.pipeline/103-full-rank-compression-peeled-odd: \
		$(LIB)/103-full-rank-compress.jl project.yml 103-full-rank-compress-peeled-odd.yml \
		.pipeline/101-averaged-m-modes-peeled-odd \
		.pipeline/101-averaged-transfer-matrix \
		.pipeline/102-noise-covariance-matrix-odd
	$(call launch-remote,1)

.pipeline/112-foreground-filter-peeled-odd-extreme: \
		$(LIB)/112-foreground-filter.jl project.yml 112-foreground-filter-peeled-odd-extreme.yml \
		.pipeline/103-full-rank-compression-peeled-odd \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/121-quadratic-estimator-peeled-odd-extreme-spherical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-peeled-odd-extreme-spherical.yml \
	    .pipeline/112-foreground-filter-peeled-odd-extreme \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-peeled-odd-extreme-cylindrical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-peeled-odd-extreme-cylindrical.yml \
	    .pipeline/112-foreground-filter-peeled-odd-extreme \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-peeled-odd-extreme-angular: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-peeled-odd-extreme-angular.yml \
	    .pipeline/112-foreground-filter-peeled-odd-extreme \
		.pipeline/120-basis-covariance-matrices-angular
	$(call launch-remote,4)

.pipeline/112-foreground-filter-peeled-odd-moderate: \
		$(LIB)/112-foreground-filter.jl project.yml 112-foreground-filter-peeled-odd-moderate.yml \
		.pipeline/103-full-rank-compression-peeled-odd \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/121-quadratic-estimator-peeled-odd-moderate-spherical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-peeled-odd-moderate-spherical.yml \
	    .pipeline/112-foreground-filter-peeled-odd-moderate \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-peeled-odd-moderate-cylindrical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-peeled-odd-moderate-cylindrical.yml \
	    .pipeline/112-foreground-filter-peeled-odd-moderate \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-peeled-odd-moderate-angular: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-peeled-odd-moderate-angular.yml \
	    .pipeline/112-foreground-filter-peeled-odd-moderate \
		.pipeline/120-basis-covariance-matrices-angular
	$(call launch-remote,4)

.pipeline/112-foreground-filter-peeled-odd-mild: \
		$(LIB)/112-foreground-filter.jl project.yml 112-foreground-filter-peeled-odd-mild.yml \
		.pipeline/103-full-rank-compression-peeled-odd \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/121-quadratic-estimator-peeled-odd-mild-spherical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-peeled-odd-mild-spherical.yml \
	    .pipeline/112-foreground-filter-peeled-odd-mild \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-peeled-odd-mild-cylindrical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-peeled-odd-mild-cylindrical.yml \
	    .pipeline/112-foreground-filter-peeled-odd-mild \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-peeled-odd-mild-angular: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-peeled-odd-mild-angular.yml \
	    .pipeline/112-foreground-filter-peeled-odd-mild \
		.pipeline/120-basis-covariance-matrices-angular
	$(call launch-remote,4)

.pipeline/030-m-modes-peeled-even: \
		$(LIB)/030-getmmodes.jl project.yml 030-getmmodes-peeled-even.yml \
		.pipeline/001-peeled-transposed-data \
		.pipeline/002-flagged-peeled-data \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/030-m-modes-interpolated-peeled-even: \
		$(LIB)/030-getmmodes.jl project.yml 030-getmmodes-interpolated-peeled-even.yml \
		.pipeline/001-peeled-transposed-data \
		.pipeline/002-flagged-peeled-data \
		.pipeline/032-predicted-visibilities-peeled \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-peeled-even: \
		$(LIB)/031-tikhonov.jl project.yml 031-tikhonov-peeled-even.yml \
		.pipeline/030-m-modes-peeled-even \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-peeled-even: \
		$(LIB)/031-tikhonov.jl project.yml 031-tikhonov-channels-peeled-even.yml \
		.pipeline/030-m-modes-peeled-even \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-interpolated-peeled-even: \
		$(LIB)/031-tikhonov.jl project.yml 031-tikhonov-interpolated-peeled-even.yml \
		.pipeline/030-m-modes-interpolated-peeled-even \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-interpolated-peeled-even: \
		$(LIB)/031-tikhonov.jl project.yml 031-tikhonov-channels-interpolated-peeled-even.yml \
		.pipeline/030-m-modes-interpolated-peeled-even \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/101-averaged-m-modes-peeled-even: \
		$(LIB)/101-average-channels.jl project.yml 101-average-channels-m-modes-peeled-even.yml \
		.pipeline/030-m-modes-interpolated-peeled-even
	$(call launch-remote,1)

.pipeline/103-full-rank-compression-peeled-even: \
		$(LIB)/103-full-rank-compress.jl project.yml 103-full-rank-compress-peeled-even.yml \
		.pipeline/101-averaged-m-modes-peeled-even \
		.pipeline/101-averaged-transfer-matrix \
		.pipeline/102-noise-covariance-matrix-even
	$(call launch-remote,1)

.pipeline/112-foreground-filter-peeled-even-extreme: \
		$(LIB)/112-foreground-filter.jl project.yml 112-foreground-filter-peeled-even-extreme.yml \
		.pipeline/103-full-rank-compression-peeled-even \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/121-quadratic-estimator-peeled-even-extreme-spherical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-peeled-even-extreme-spherical.yml \
	    .pipeline/112-foreground-filter-peeled-even-extreme \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-peeled-even-extreme-cylindrical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-peeled-even-extreme-cylindrical.yml \
	    .pipeline/112-foreground-filter-peeled-even-extreme \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-peeled-even-extreme-angular: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-peeled-even-extreme-angular.yml \
	    .pipeline/112-foreground-filter-peeled-even-extreme \
		.pipeline/120-basis-covariance-matrices-angular
	$(call launch-remote,4)

.pipeline/112-foreground-filter-peeled-even-moderate: \
		$(LIB)/112-foreground-filter.jl project.yml 112-foreground-filter-peeled-even-moderate.yml \
		.pipeline/103-full-rank-compression-peeled-even \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/121-quadratic-estimator-peeled-even-moderate-spherical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-peeled-even-moderate-spherical.yml \
	    .pipeline/112-foreground-filter-peeled-even-moderate \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-peeled-even-moderate-cylindrical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-peeled-even-moderate-cylindrical.yml \
	    .pipeline/112-foreground-filter-peeled-even-moderate \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-peeled-even-moderate-angular: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-peeled-even-moderate-angular.yml \
	    .pipeline/112-foreground-filter-peeled-even-moderate \
		.pipeline/120-basis-covariance-matrices-angular
	$(call launch-remote,4)

.pipeline/112-foreground-filter-peeled-even-mild: \
		$(LIB)/112-foreground-filter.jl project.yml 112-foreground-filter-peeled-even-mild.yml \
		.pipeline/103-full-rank-compression-peeled-even \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/121-quadratic-estimator-peeled-even-mild-spherical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-peeled-even-mild-spherical.yml \
	    .pipeline/112-foreground-filter-peeled-even-mild \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-peeled-even-mild-cylindrical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-peeled-even-mild-cylindrical.yml \
	    .pipeline/112-foreground-filter-peeled-even-mild \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-peeled-even-mild-angular: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-peeled-even-mild-angular.yml \
	    .pipeline/112-foreground-filter-peeled-even-mild \
		.pipeline/120-basis-covariance-matrices-angular
	$(call launch-remote,4)

.pipeline/032-predicted-visibilities-peeled: \
		$(LIB)/032-predict-visibilities.jl project.yml 032-predict-visibilities-peeled.yml \
		.pipeline/031-dirty-map-peeled-all \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/030-m-modes-recalibrated-all: \
		$(LIB)/030-getmmodes.jl project.yml 030-getmmodes-recalibrated-all.yml \
		.pipeline/001-recalibrated-transposed-data \
		.pipeline/002-flagged-peeled-data \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/030-m-modes-interpolated-recalibrated-all: \
		$(LIB)/030-getmmodes.jl project.yml 030-getmmodes-interpolated-recalibrated-all.yml \
		.pipeline/001-recalibrated-transposed-data \
		.pipeline/002-flagged-peeled-data \
		.pipeline/032-predicted-visibilities-recalibrated \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-recalibrated-all: \
		$(LIB)/031-tikhonov.jl project.yml 031-tikhonov-recalibrated-all.yml \
		.pipeline/030-m-modes-recalibrated-all \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-recalibrated-all: \
		$(LIB)/031-tikhonov.jl project.yml 031-tikhonov-channels-recalibrated-all.yml \
		.pipeline/030-m-modes-recalibrated-all \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-interpolated-recalibrated-all: \
		$(LIB)/031-tikhonov.jl project.yml 031-tikhonov-interpolated-recalibrated-all.yml \
		.pipeline/030-m-modes-interpolated-recalibrated-all \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-interpolated-recalibrated-all: \
		$(LIB)/031-tikhonov.jl project.yml 031-tikhonov-channels-interpolated-recalibrated-all.yml \
		.pipeline/030-m-modes-interpolated-recalibrated-all \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/101-averaged-m-modes-recalibrated-all: \
		$(LIB)/101-average-channels.jl project.yml 101-average-channels-m-modes-recalibrated-all.yml \
		.pipeline/030-m-modes-interpolated-recalibrated-all
	$(call launch-remote,1)

.pipeline/103-full-rank-compression-recalibrated-all: \
		$(LIB)/103-full-rank-compress.jl project.yml 103-full-rank-compress-recalibrated-all.yml \
		.pipeline/101-averaged-m-modes-recalibrated-all \
		.pipeline/101-averaged-transfer-matrix \
		.pipeline/102-noise-covariance-matrix-all
	$(call launch-remote,1)

.pipeline/112-foreground-filter-recalibrated-all-extreme: \
		$(LIB)/112-foreground-filter.jl project.yml 112-foreground-filter-recalibrated-all-extreme.yml \
		.pipeline/103-full-rank-compression-recalibrated-all \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/121-quadratic-estimator-recalibrated-all-extreme-spherical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-recalibrated-all-extreme-spherical.yml \
	    .pipeline/112-foreground-filter-recalibrated-all-extreme \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-recalibrated-all-extreme-cylindrical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-recalibrated-all-extreme-cylindrical.yml \
	    .pipeline/112-foreground-filter-recalibrated-all-extreme \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-recalibrated-all-extreme-angular: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-recalibrated-all-extreme-angular.yml \
	    .pipeline/112-foreground-filter-recalibrated-all-extreme \
		.pipeline/120-basis-covariance-matrices-angular
	$(call launch-remote,4)

.pipeline/112-foreground-filter-recalibrated-all-moderate: \
		$(LIB)/112-foreground-filter.jl project.yml 112-foreground-filter-recalibrated-all-moderate.yml \
		.pipeline/103-full-rank-compression-recalibrated-all \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/121-quadratic-estimator-recalibrated-all-moderate-spherical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-recalibrated-all-moderate-spherical.yml \
	    .pipeline/112-foreground-filter-recalibrated-all-moderate \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-recalibrated-all-moderate-cylindrical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-recalibrated-all-moderate-cylindrical.yml \
	    .pipeline/112-foreground-filter-recalibrated-all-moderate \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-recalibrated-all-moderate-angular: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-recalibrated-all-moderate-angular.yml \
	    .pipeline/112-foreground-filter-recalibrated-all-moderate \
		.pipeline/120-basis-covariance-matrices-angular
	$(call launch-remote,4)

.pipeline/112-foreground-filter-recalibrated-all-mild: \
		$(LIB)/112-foreground-filter.jl project.yml 112-foreground-filter-recalibrated-all-mild.yml \
		.pipeline/103-full-rank-compression-recalibrated-all \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/121-quadratic-estimator-recalibrated-all-mild-spherical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-recalibrated-all-mild-spherical.yml \
	    .pipeline/112-foreground-filter-recalibrated-all-mild \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-recalibrated-all-mild-cylindrical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-recalibrated-all-mild-cylindrical.yml \
	    .pipeline/112-foreground-filter-recalibrated-all-mild \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-recalibrated-all-mild-angular: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-recalibrated-all-mild-angular.yml \
	    .pipeline/112-foreground-filter-recalibrated-all-mild \
		.pipeline/120-basis-covariance-matrices-angular
	$(call launch-remote,4)

.pipeline/030-m-modes-recalibrated-odd: \
		$(LIB)/030-getmmodes.jl project.yml 030-getmmodes-recalibrated-odd.yml \
		.pipeline/001-recalibrated-transposed-data \
		.pipeline/002-flagged-peeled-data \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/030-m-modes-interpolated-recalibrated-odd: \
		$(LIB)/030-getmmodes.jl project.yml 030-getmmodes-interpolated-recalibrated-odd.yml \
		.pipeline/001-recalibrated-transposed-data \
		.pipeline/002-flagged-peeled-data \
		.pipeline/032-predicted-visibilities-recalibrated \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-recalibrated-odd: \
		$(LIB)/031-tikhonov.jl project.yml 031-tikhonov-recalibrated-odd.yml \
		.pipeline/030-m-modes-recalibrated-odd \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-recalibrated-odd: \
		$(LIB)/031-tikhonov.jl project.yml 031-tikhonov-channels-recalibrated-odd.yml \
		.pipeline/030-m-modes-recalibrated-odd \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-interpolated-recalibrated-odd: \
		$(LIB)/031-tikhonov.jl project.yml 031-tikhonov-interpolated-recalibrated-odd.yml \
		.pipeline/030-m-modes-interpolated-recalibrated-odd \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-interpolated-recalibrated-odd: \
		$(LIB)/031-tikhonov.jl project.yml 031-tikhonov-channels-interpolated-recalibrated-odd.yml \
		.pipeline/030-m-modes-interpolated-recalibrated-odd \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/101-averaged-m-modes-recalibrated-odd: \
		$(LIB)/101-average-channels.jl project.yml 101-average-channels-m-modes-recalibrated-odd.yml \
		.pipeline/030-m-modes-interpolated-recalibrated-odd
	$(call launch-remote,1)

.pipeline/103-full-rank-compression-recalibrated-odd: \
		$(LIB)/103-full-rank-compress.jl project.yml 103-full-rank-compress-recalibrated-odd.yml \
		.pipeline/101-averaged-m-modes-recalibrated-odd \
		.pipeline/101-averaged-transfer-matrix \
		.pipeline/102-noise-covariance-matrix-odd
	$(call launch-remote,1)

.pipeline/112-foreground-filter-recalibrated-odd-extreme: \
		$(LIB)/112-foreground-filter.jl project.yml 112-foreground-filter-recalibrated-odd-extreme.yml \
		.pipeline/103-full-rank-compression-recalibrated-odd \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/121-quadratic-estimator-recalibrated-odd-extreme-spherical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-recalibrated-odd-extreme-spherical.yml \
	    .pipeline/112-foreground-filter-recalibrated-odd-extreme \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-recalibrated-odd-extreme-cylindrical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-recalibrated-odd-extreme-cylindrical.yml \
	    .pipeline/112-foreground-filter-recalibrated-odd-extreme \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-recalibrated-odd-extreme-angular: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-recalibrated-odd-extreme-angular.yml \
	    .pipeline/112-foreground-filter-recalibrated-odd-extreme \
		.pipeline/120-basis-covariance-matrices-angular
	$(call launch-remote,4)

.pipeline/112-foreground-filter-recalibrated-odd-moderate: \
		$(LIB)/112-foreground-filter.jl project.yml 112-foreground-filter-recalibrated-odd-moderate.yml \
		.pipeline/103-full-rank-compression-recalibrated-odd \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/121-quadratic-estimator-recalibrated-odd-moderate-spherical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-recalibrated-odd-moderate-spherical.yml \
	    .pipeline/112-foreground-filter-recalibrated-odd-moderate \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-recalibrated-odd-moderate-cylindrical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-recalibrated-odd-moderate-cylindrical.yml \
	    .pipeline/112-foreground-filter-recalibrated-odd-moderate \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-recalibrated-odd-moderate-angular: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-recalibrated-odd-moderate-angular.yml \
	    .pipeline/112-foreground-filter-recalibrated-odd-moderate \
		.pipeline/120-basis-covariance-matrices-angular
	$(call launch-remote,4)

.pipeline/112-foreground-filter-recalibrated-odd-mild: \
		$(LIB)/112-foreground-filter.jl project.yml 112-foreground-filter-recalibrated-odd-mild.yml \
		.pipeline/103-full-rank-compression-recalibrated-odd \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/121-quadratic-estimator-recalibrated-odd-mild-spherical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-recalibrated-odd-mild-spherical.yml \
	    .pipeline/112-foreground-filter-recalibrated-odd-mild \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-recalibrated-odd-mild-cylindrical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-recalibrated-odd-mild-cylindrical.yml \
	    .pipeline/112-foreground-filter-recalibrated-odd-mild \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-recalibrated-odd-mild-angular: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-recalibrated-odd-mild-angular.yml \
	    .pipeline/112-foreground-filter-recalibrated-odd-mild \
		.pipeline/120-basis-covariance-matrices-angular
	$(call launch-remote,4)

.pipeline/030-m-modes-recalibrated-even: \
		$(LIB)/030-getmmodes.jl project.yml 030-getmmodes-recalibrated-even.yml \
		.pipeline/001-recalibrated-transposed-data \
		.pipeline/002-flagged-peeled-data \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/030-m-modes-interpolated-recalibrated-even: \
		$(LIB)/030-getmmodes.jl project.yml 030-getmmodes-interpolated-recalibrated-even.yml \
		.pipeline/001-recalibrated-transposed-data \
		.pipeline/002-flagged-peeled-data \
		.pipeline/032-predicted-visibilities-recalibrated \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-recalibrated-even: \
		$(LIB)/031-tikhonov.jl project.yml 031-tikhonov-recalibrated-even.yml \
		.pipeline/030-m-modes-recalibrated-even \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-recalibrated-even: \
		$(LIB)/031-tikhonov.jl project.yml 031-tikhonov-channels-recalibrated-even.yml \
		.pipeline/030-m-modes-recalibrated-even \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-map-interpolated-recalibrated-even: \
		$(LIB)/031-tikhonov.jl project.yml 031-tikhonov-interpolated-recalibrated-even.yml \
		.pipeline/030-m-modes-interpolated-recalibrated-even \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/031-dirty-channel-maps-interpolated-recalibrated-even: \
		$(LIB)/031-tikhonov.jl project.yml 031-tikhonov-channels-interpolated-recalibrated-even.yml \
		.pipeline/030-m-modes-interpolated-recalibrated-even \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

.pipeline/101-averaged-m-modes-recalibrated-even: \
		$(LIB)/101-average-channels.jl project.yml 101-average-channels-m-modes-recalibrated-even.yml \
		.pipeline/030-m-modes-interpolated-recalibrated-even
	$(call launch-remote,1)

.pipeline/103-full-rank-compression-recalibrated-even: \
		$(LIB)/103-full-rank-compress.jl project.yml 103-full-rank-compress-recalibrated-even.yml \
		.pipeline/101-averaged-m-modes-recalibrated-even \
		.pipeline/101-averaged-transfer-matrix \
		.pipeline/102-noise-covariance-matrix-even
	$(call launch-remote,1)

.pipeline/112-foreground-filter-recalibrated-even-extreme: \
		$(LIB)/112-foreground-filter.jl project.yml 112-foreground-filter-recalibrated-even-extreme.yml \
		.pipeline/103-full-rank-compression-recalibrated-even \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/121-quadratic-estimator-recalibrated-even-extreme-spherical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-recalibrated-even-extreme-spherical.yml \
	    .pipeline/112-foreground-filter-recalibrated-even-extreme \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-recalibrated-even-extreme-cylindrical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-recalibrated-even-extreme-cylindrical.yml \
	    .pipeline/112-foreground-filter-recalibrated-even-extreme \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-recalibrated-even-extreme-angular: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-recalibrated-even-extreme-angular.yml \
	    .pipeline/112-foreground-filter-recalibrated-even-extreme \
		.pipeline/120-basis-covariance-matrices-angular
	$(call launch-remote,4)

.pipeline/112-foreground-filter-recalibrated-even-moderate: \
		$(LIB)/112-foreground-filter.jl project.yml 112-foreground-filter-recalibrated-even-moderate.yml \
		.pipeline/103-full-rank-compression-recalibrated-even \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/121-quadratic-estimator-recalibrated-even-moderate-spherical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-recalibrated-even-moderate-spherical.yml \
	    .pipeline/112-foreground-filter-recalibrated-even-moderate \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-recalibrated-even-moderate-cylindrical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-recalibrated-even-moderate-cylindrical.yml \
	    .pipeline/112-foreground-filter-recalibrated-even-moderate \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-recalibrated-even-moderate-angular: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-recalibrated-even-moderate-angular.yml \
	    .pipeline/112-foreground-filter-recalibrated-even-moderate \
		.pipeline/120-basis-covariance-matrices-angular
	$(call launch-remote,4)

.pipeline/112-foreground-filter-recalibrated-even-mild: \
		$(LIB)/112-foreground-filter.jl project.yml 112-foreground-filter-recalibrated-even-mild.yml \
		.pipeline/103-full-rank-compression-recalibrated-even \
		.pipeline/110-foreground-covariance-matrix \
		.pipeline/111-signal-covariance-matrix
	$(call launch-remote,2)

.pipeline/121-quadratic-estimator-recalibrated-even-mild-spherical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-recalibrated-even-mild-spherical.yml \
	    .pipeline/112-foreground-filter-recalibrated-even-mild \
		.pipeline/120-basis-covariance-matrices-spherical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-recalibrated-even-mild-cylindrical: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-recalibrated-even-mild-cylindrical.yml \
	    .pipeline/112-foreground-filter-recalibrated-even-mild \
		.pipeline/120-basis-covariance-matrices-cylindrical
	$(call launch-remote,4)

.pipeline/121-quadratic-estimator-recalibrated-even-mild-angular: \
		$(LIB)/121-quadratic-estimator.jl project.yml 121-quadratic-estimator-recalibrated-even-mild-angular.yml \
	    .pipeline/112-foreground-filter-recalibrated-even-mild \
		.pipeline/120-basis-covariance-matrices-angular
	$(call launch-remote,4)

.pipeline/032-predicted-visibilities-recalibrated: \
		$(LIB)/032-predict-visibilities.jl project.yml 032-predict-visibilities-recalibrated.yml \
		.pipeline/031-dirty-map-recalibrated-all \
		.pipeline/100-transfer-matrix
	$(call launch-remote,1)

