.PHONY: all

BIN=../../bin
LIB=../../lib
LAUNCH=$(BIN)/launch.jl

.pipeline/data: data.yml metadata.yml
	$(LAUNCH) --local-workers 2 --driver 000-getdata.jl --metadata metadata.yml --config data.yml






