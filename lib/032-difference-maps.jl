module Driver

using LibHealpix
using ProgressMeter
using YAML

include("Project.jl")

struct Config
    inputs :: Vector{String}
    output_directory :: String
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["inputs"],
           get(dict, "output-directory", ""))
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    difference(project, config)
end

function difference(project, config)
    input_path  = Project.workspace(project)
    output_path = joinpath(input_path, config.output_directory)
    isdir(output_path) || mkpath(output_path)
    prg = Progress(length(config.inputs)-1)
    for idx = 1:length(config.inputs)-1
        file1 = config.inputs[idx]
        file2 = config.inputs[idx+1]
        file3 = @sprintf("033-difference-%s-%s.fits",
                         replace(basename(file2), ".fits", ""),
                         replace(basename(file1), ".fits", ""))
        map1 = readhealpix(joinpath(input_path, file1))
        map2 = readhealpix(joinpath(input_path, file2))
        map3 = map2 - map1
        writehealpix(joinpath(output_path, file3), map3, replace=true)
        next!(prg)
    end
end

end

