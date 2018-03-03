module Driver

using BPJSpec
using FileIO, JLD2

include("../lib/Common.jl"); using .Common

function go(spw, name)
    path = getdir(spw, name)
    F, model = load(joinpath(path, "fisher-matrix.jld2"), "matrix", "model")

    λ = minimum(eigvals(F))
    if λ < 0
        F -= 1.1*λ*I
    end

    M⁻¹ = BPJSpec.inverse_mixing_matrix(F, strategy=:uncorrelated)
    W   = BPJSpec.window_functions(F, M⁻¹)
    Σ   = BPJSpec.windowed_covariance(F, M⁻¹)
    σ   = sqrt.(diag(Σ))

    save(joinpath(path, "quadratic-estimator.jld2"),
         "21-cm-signal-model", model,
         "fisher-information", F,
         "inverse-mixing-matrix", M⁻¹,
         "window-functions", W,
         "standard-errors", σ)
end

end

