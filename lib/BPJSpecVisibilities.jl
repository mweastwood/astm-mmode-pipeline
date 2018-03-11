module BPJSpecVisibilities

export Visibilities64, Visibilities128

using BPJSpec
using ..Project

const Visibilities64  = BPJSpec.BlockMatrix{Array{Complex64,  3}, 1}
const Visibilities128 = BPJSpec.BlockMatrix{Array{Complex128, 3}, 1}

for T in (:Visibilities64, :Visibilities128)
    @eval function $T(path::String, length::Int)
        $T(MultipleFiles(path), BPJSpec.NoMetadata(length))
    end
    @eval function $T(project::Project.ProjectMetadata, filename::String, length::Int)
        $T(joinpath(Project.workspace(project), filename), length)
    end
    @eval function $T(project::Project.ProjectMetadata, filename::String)
        $T(joinpath(Project.workspace(project), filename))
    end
end

end

