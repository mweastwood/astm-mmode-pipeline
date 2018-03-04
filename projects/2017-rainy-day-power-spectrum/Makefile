.PHONY: all

BIN=../../bin
LIB=../../lib
LAUNCH=$(BIN)/launch.jl

.pipeline/raw-data: $(LIB)/000-getdata.jl project.yml dada2ms.yml raw-data.yml
	$(LAUNCH) --local-workers 8 000-getdata.jl project.yml dada2ms.yml raw-data.yml






