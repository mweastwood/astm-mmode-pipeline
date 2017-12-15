.PHONY: test

test:
	cd pipeline/02-peel; ./go.jl 18 rainy

workspace/spw18/rainy/peeled-visibilities.jld2: workspace/spw18/rainy/calibrated-visibilities.jld2
	cd pipeline/02-peel; ./go.jl 18 rainy

