.PHONY: test

test:
	cd pipeline/02-peel; ./go.jl 18 rainy

workspace/spw18/rainy/peeled-visibilities.jld2: workspace/spw18/rainy/calibrated-visibilities.jld2
	cd pipeline/02-peel; ./go.jl 18 rainy

workspace/spw18/rainy/transposed-visibilities.jld2: workspace/spw18/rainy/peeled-visibilities.jld2
	cd pipeline/10-transpose; ./go.jl 18 rainy

workspace/spw18/rainy/folded-visibilities.jld2: workspace/spw18/rainy/transposed-visibilities.jld2
	cd pipeline/20-fold; ./go.jl 18 rainy

