function difference(spw)
    dir = getdir(spw)
    folded, flags = load(joinpath(dir, "folded-visibilities.jld"), "data", "flags")
    model = load(joinpath(dir, "model-visibilities.jld"), "data")
    diff = folded - model
    save(joinpath(dir, "differenced-visibilities.jld"), "data", diff, "flags", flags)
end

# Differencing the model from the measured visibilities is actually a complicated operation.
# Pictorially, what's going on here is that we started with a set of measured visibilities that
# include some contribution from the sky and some contribution from RFI and cross-talk. When we
# "invert" the transfer matrix and solve for the spherical harmonic coefficients of the sky, we are
# projecting all of these components onto the sky basis. So when we multiply by the transfer matrix
# again, the sky contribution to the visibilities is unchanged, but the RFI and cross-talk
# components are modified by the projection. Therefore the process of differencing measured and
# model visibilities is:
#
#   (measured) - (model)
#       = (sky + RFI) - (sky + projected RFI)
#       = RFI - projected RFI
#       = (1 - projection) * RFI
#
# So by doing this difference we have removed the sky contribution, but we'd like to invert the
# projection process to the best of our ability and obtain a model for the RFI that we can then
# subtract from the measured visibilities.
#
# So what is the projection matrix in this case?
#
#   projection = B (B'B + ϵI)⁻¹ B'
#
# This is an extremely large singular matrix where the eigenvalues are either 1 -- for sky-like
# components -- or 0. For the m=0 block, this matrix is Nbase x Nbase, but for m≥1 this matrix is
# 2Nbase x 2Nbase. This analysis assumed ϵ<<1. Because we want to do the least possible amount of
# work, we're going to begin by taking the singular value decomposition of B because all of these
# operations then reduce to simple operations on the singular values.








#function svd_components(spw)
#    dir = getdir(spw)
#    data, flags = load(joinpath(dir, "differenced-visibilities.jld"), "data", "flags")
#    data[flags] = 0
#    BLAS.set_num_threads(16)
#    U, S, V = svd(data)
#    save(joinpath(dir, "differenced-visibilities-svd.jld"), "U", U, "S", S, "V", V, compress=true)
#end
#
#function image_component(spw, U, idx)
#    Nbase = size(U, 1)
#    output = Visibilities(Nbase, 109)
#    output.data[:] = zero(JonesMatrix)
#    output.flags[:] = true
#    for α = 1:Nbase
#        vis = U[α, idx]
#        output.data[α, 55] = JonesMatrix(vis, 0, 0, vis)
#        output.flags[α, 55] = false
#    end
#
#    dadas = listdadas(spw)
#    ms, ms_path = dada2ms(dadas[1])
#    TTCal.write(ms, "DATA", output)
#    finalize(ms)
#    image_path = joinpath(getdir(spw), "tmp", @sprintf("differenced-visibilities-component-%05d", idx))
#    wsclean(ms_path, image_path, j=8)
#    rm(ms_path, recursive=true)
#end
#
#function discard_components(spw, N)
#    dir = getdir(spw)
#    U, S, V = load(joinpath(dir, "differenced-visibilities-svd.jld"), "U", "S", "V")
#    discard_components(spw, U, S, V, N)
#end
#
#function discard_components(spw, U, S, V, N)
#    BLAS.set_num_threads(16)
#    S[N+1:end] = 0
#    # Multiplying a Matrix{Float64} with a Matrix{Complex128} seems to trigger the generic matrix
#    # multiplication code path. So let's convert from Float64 to Complex128 in order to trigger the
#    # BLAS code path.
#    SV = diagm(Vector{Complex128}(S)) * V'
#    data = U*SV
#    summed = sum(data, 2)
#
#    Nbase = length(summed)
#    output = Visibilities(Nbase, 109)
#    output.data[:] = zero(JonesMatrix)
#    output.flags[:] = true
#    for α = 1:Nbase
#        vis = summed[α]
#        output.data[α, 55] = JonesMatrix(vis, 0, 0, vis)
#        output.flags[α, 55] = false
#    end
#
#    dadas = listdadas(spw)
#    ms, ms_path = dada2ms(dadas[1])
#    TTCal.write(ms, "DATA", output)
#    finalize(ms)
#    image_path = joinpath(getdir(spw), "differenced-discarded-visibilities")
#    wsclean(ms_path, image_path, j=8)
#    rm(ms_path, recursive=true)
#
#    save(joinpath(getdir(spw), "differenced-discarded-visibilities.jld"),
#         "data", data, "number", N, compress=true)
#
#    undo_the_difference(spw)
#
#    data
#end
#
#function undo_the_difference(spw)
#    dir = getdir(spw)
#    data, flags = load(joinpath(dir, "folded-visibilities.jld"), "data", "flags")
#    differenced_discarded = load(joinpath(dir, "differenced-discarded-visibilities.jld"), "data")
#    undone = data - differenced_discarded
#    save(joinpath(dir, "restored-visibilities.jld"), "data", undone, "flags", flags)
#end

