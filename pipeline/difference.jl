function difference(spw)
    dir = getdir(spw)
    folded, flags = load(joinpath(dir, "folded-visibilities.jld"), "data", "flags")
    model = load(joinpath(dir, "model-visibilities.jld"), "data")
    diff = folded - model
    save(joinpath(dir, "differenced-visibilities.jld"), "data", diff, "flags", flags)
end

function svd_components(spw)
    dir = getdir(spw)
    data, flags = load(joinpath(dir, "differenced-visibilities.jld"), "data", "flags")
    data[flags] = 0
    BLAS.set_num_threads(16)
    U, S, V = svd(data)
    save(joinpath(dir, "differenced-visibilities-svd.jld"), "U", U, "S", S, "V", V)
end

function image_component(spw, U, idx)
    Nbase = size(U, 1)
    output = Visibilities(Nbase, 109)
    output.data[:] = zero(JonesMatrix)
    output.flags[:] = true
    for α = 1:Nbase
        vis = U[α, idx]
        output.data[α, 55] = JonesMatrix(vis, 0, 0, vis)
        output.flags[α, 55] = false
    end

    dadas = listdadas(spw)
    ms, ms_path = dada2ms(dadas[1])
    TTCal.write(ms, "DATA", output)
    finalize(ms)
    image_path = joinpath(getdir(spw), "tmp", @sprintf("differenced-visibilities-component-%05d", idx))
    wsclean(ms_path, image_path, j=8)
    rm(ms_path, recursive=true)
end

function discard_and_image_components(spw, U, S, V, range)
    BLAS.set_num_threads(16)
    S[range] = 0
    # Multiplying a Matrix{Float64} with a Matrix{Complex128} seems to trigger the generic matrix
    # multiplication code path. So let's convert from Float64 to Complex128 in order to trigger the
    # BLAS code path.
    SV = diagm(Vector{Complex128}(S)) * V'
    data = U*SV
    summed = sum(data, 2)

    Nbase = length(summed)
    output = Visibilities(Nbase, 109)
    output.data[:] = zero(JonesMatrix)
    output.flags[:] = true
    for α = 1:Nbase
        vis = summed[α]
        output.data[α, 55] = JonesMatrix(vis, 0, 0, vis)
        output.flags[α, 55] = false
    end

    dadas = listdadas(spw)
    ms, ms_path = dada2ms(dadas[1])
    TTCal.write(ms, "DATA", output)
    finalize(ms)
    image_path = joinpath(getdir(spw), "differenced-discarded-visibilities")
    wsclean(ms_path, image_path, j=8)
    rm(ms_path, recursive=true)

    save(joinpath(getdir(spw), "differenced-discarded-visibilities.jld"), "data", data, "range", range)
    data
end

function undo_the_differencing(spw)
    dir = getdir(spw)
    flags = load(joinpath(dir, "folded-visibilities.jld"), "flags")
    differenced_discarded = load(joinpath(dir, "differenced-discarded-visibilities.jld"), "data")
    model = load(joinpath(dir, "model-visibilities.jld"), "data")
    restored = model + differenced_discarded
    save(joinpath(dir, "restored-visibilities.jld"), "data", data, "flags", flags)
end

