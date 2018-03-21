.PHONY: all raw flag calibrate
all: dirty-map
raw: .pipeline/000-raw-data
flag: .pipeline/001-flagged-raw-data
calibrate: .pipeline/002-calibrated-data

BIN=../../bin
LIB=../../lib
JULIA=julia-0.6 --color=yes
LAUNCH=$(JULIA) $(BIN)/launch.jl

.pipeline/000-raw-data: $(LIB)/000-getdata.jl project.yml dada2ms.yml 000-getdata.yml
	$(LAUNCH) $^

.pipeline/001-flagged-raw-data: .pipeline/000-raw-data \
		$(LIB)/001-flag.jl project.yml 001-flag-raw.yml
	$(LAUNCH) $(filter-out .pipeline/%,$^)

.pipeline/002-calibrated-data: .pipeline/001-flagged-raw-data \
		$(LIB)/002-calibrate.jl project.yml wsclean.yml 002-calibrate.yml
	$(LAUNCH) $(filter-out .pipeline/%,$^)

