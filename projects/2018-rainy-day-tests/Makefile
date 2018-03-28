.PHONY: raw-accumulated
raw-accumulated: \
	.pipeline/000-getdata-accumulated-spw00 \
	.pipeline/000-getdata-accumulated-spw01 \
	.pipeline/000-getdata-accumulated-spw02 \
	.pipeline/000-getdata-accumulated-spw03 \
	.pipeline/000-getdata-accumulated-spw04 \
	.pipeline/000-getdata-accumulated-spw05 \
	.pipeline/000-getdata-accumulated-spw06 \
	.pipeline/000-getdata-accumulated-spw07 \
	.pipeline/000-getdata-accumulated-spw08 \
	.pipeline/000-getdata-accumulated-spw09 \
	.pipeline/000-getdata-accumulated-spw10 \
	.pipeline/000-getdata-accumulated-spw11 \
	.pipeline/000-getdata-accumulated-spw12 \
	.pipeline/000-getdata-accumulated-spw13 \
	.pipeline/000-getdata-accumulated-spw14 \
	.pipeline/000-getdata-accumulated-spw15 \
	.pipeline/000-getdata-accumulated-spw16 \
	.pipeline/000-getdata-accumulated-spw17 \
	.pipeline/000-getdata-accumulated-spw18 \
	.pipeline/000-getdata-accumulated-spw19 \
	.pipeline/000-getdata-accumulated-spw20 \
	.pipeline/000-getdata-accumulated-spw21

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

.pipeline/000-getdata-accumulated-spw%: \
		$(LIB)/000-getdata.jl project.yml dada2ms.yml 000-getdata-accumulated-spw%.yml
	$(call launch-remote,2)

#.pipeline/001-flagged-raw-data: .pipeline/000-raw-data \
#		$(LIB)/001-flag.jl project.yml 001-flag-raw.yml
#	$(LAUNCH) $(filter-out .pipeline/%,$^)
#
#.pipeline/002-calibrated-data: .pipeline/001-flagged-raw-data \
#		$(LIB)/002-calibrate.jl project.yml wsclean.yml 002-calibrate.yml
#	$(LAUNCH) $(filter-out .pipeline/%,$^)

