function restore_no_point_sources(spw, dataset, target)
    catalogs = joinpath(workspace, "catalogs")
    nvss = readdlm(joinpath(catalogs, "nvss.txt"), '|', Float64, skipstart=3)


end

