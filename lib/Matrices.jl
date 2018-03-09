module Matrices

using BPJSpec

const Visibilities = BPJSpec.BlockMatrix{Array{Complex64, 3}, 1}
function Visibilities(path::String, length::Int)
    Visibilities(MultipleFiles(path), BPJSpec.NoMetadata(length))
end

end

