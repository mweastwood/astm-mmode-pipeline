function residualsvd(spw, input_vis="visibilities", input_model="visibilities-model")
    Lumberjack.info("Computing SVD of the residuals in spectral window $spw")
    dir = getdir(spw)

    measured = GriddedVisibilities(joinpath(dir, input_vis))
    Lumberjack.info("Using measured visibilities $(measured.path)")

    model = GriddedVisibilities(joinpath(dir, input_model))
    Lumberjack.info("Using model visibilities $(model.path)")

    Nbase = measured.Nbase
    Ntime = measured.Ntime
    frequencies = measured.frequencies
    origin = measured.origin

    @time measured_grid = measured[1]
    @time model_grid = model[1]
    @time grid = zeros(Complex128, Nbase, Ntime)
    @time for j = 1:Ntime, i = 1:Nbase
        grid[i,j] = ifelse(measured_grid[i,j] == 0, complex(0.0), measured_grid[i,j] - model_grid[i,j])
    end

    Lumberjack.info("Beginning the SVD")
    @time U, S, V = svd(grid)
    Lumberjack.info("Finished the SVD")
    output = joinpath(dir, "svd.jld")
    Lumberjack.info("Saving the SVD to $output")
    save(output, "U", U, "S", S, "V", V)

    nothing
end

