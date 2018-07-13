# Estimating the angular power-spectrum with a quadratic estimator is a little easier because the
# angular covariance matrices are *much* simpler, so we can simplify a lot of the computation.

module Driver

using BPJSpec
using ProgressMeter
using YAML

struct Config
    input_mmodes           :: String
    input_transfermatrix   :: String
    input_noise_covariance :: String
    input_sky_covariance   :: String
    output                 :: String
    snr_threshold :: Float64
end

function load(file)
    dict = YAML.load(open(file))
    Config(dict["input-m-modes"],
           dict["input-transfer-matrix"],
           dict["input-noise-covariance"],
           dict["input-sky-covariance"],
           dict["output"],
           dict["snr-threshold"])
end

function go(project_file, config_file)
    project = Project.load(project_file)
    config  = load(config_file)
    angular_quadratic_estimator(project, config)
end

function angular_quadratic_estimator(project, config)
    path = Project.workspace(project)
    mmodes           = BPJSpec.load(joinpath(path, config.input_mmodes))
    transfermatrix   = BPJSpec.load(joinpath(path, config.input_transfermatrix))
    noise_covariance = BPJSpec.load(joinpath(path, config.input_noise_covariance))
    sky_covariance   = BPJSpec.load(joinpath(path, config.input_sky_covariance))
    F, Σ, q, p = _angular_quadratic_estimator(transfermatrix, mmodes,
                                              noise_covariance, sky_covariance,
                                              config.snr_threshold)
    save(joinpath(path, config.output*".jld2"),
         "fisher-information", F, "covariance", Σ, "q", q, "p", p)
end

function _angular_quadratic_estimator(transfermatrix, mmodes, noise_covariance, sky_covariance,
                                      snr_threshold)

    mmax  = transfermatrix.mmax
    Nfreq = length(transfermatrix.frequencies)
    F = Array{Matrix{Float64}}(mmax+1, Nfreq)
    q = Array{Vector{Float64}}(mmax+1, Nfreq)

    queue = collect(BPJSpec.indices(transfermatrix))
    lck = ReentrantLock()
    prg = Progress(length(queue))
    increment() = (lock(lck); next!(prg); unlock(lck))

    @sync for worker in workers()
        @async while length(queue) > 0
            m, β = shift!(queue)
            F′, q′ = remotecall_fetch(compute_F_q, worker,
                                      transfermatrix, mmodes,
                                      noise_covariance, sky_covariance,
                                      m, β, snr_threshold)
            F[m+1, β] = F′
            q[m+1, β] = q′
            increment()
        end
    end

    p, Σ = compute_p(F, q)
    F, Σ, q, p
end

function compute_F_q(transfermatrix, mmodes,
                     noise_covariance, sky_covariance,
                     m, β, snr_threshold)

    B =   transfermatrix[m, β]
    v =           mmodes[m, β]
    N = noise_covariance[m, β]    |> BPJSpec.fix
    S = B*sky_covariance[m, β]*B' |> BPJSpec.fix

    # Discard low SNR modes
    filter = snr_filter(S, N, snr_threshold)
    B = filter'*B
    v = filter'*v
    C = filter'*(N + S)*filter

    lmax = transfermatrix.mmax
    F = zeros(lmax + 1, lmax + 1)
    q = zeros(lmax + 1)
    _compute_F_q!(F, q, B, v, C, lmax, m)
end

function _compute_F_q!(F, q, B, v, C, lmax, m)
    Bv = B'*(C\v)
    for l = m:lmax
        idx1 = l - m + 1
        jdx1 = l + 1
        col1 = @view B[:, idx1]
        Ccol1 = C \ col1
        q[jdx1] = abs2(Bv[idx1])
        F[jdx1, jdx1] = abs2(dot(Ccol1, col1))
        for l′ = l+1:lmax
            idx2 = l′ - m + 1
            jdx2 = l′ + 1
            col2 = @view B[:, idx2]
            F[jdx1, jdx2] = abs2(dot(Ccol1, col2))
            F[jdx2, jdx1] = F[jdx1, jdx2]
        end 
    end
    F, q
end

function snr_filter(S, N, threshold)
    λ, V = eig(S, N)
    idx = searchsortedlast(λ, threshold)
    cut = λ .> threshold
    V[:, cut]
end

function compute_p(F, q)
    mmax  = size(F, 1) - 1
    Nfreq = size(F, 2)
    p = Array{Vector{Float64}}(Nfreq)
    Σ = Array{Matrix{Float64}}(Nfreq)
    for β = 1:Nfreq
        # Don't use any information from `m == 0`
        F′ = sum(F[2:end, 1])
        q′ = sum(q[2:end, 1])

        # Select only values of `l` that are well measured
        # TODO make this configurable
        selection = 11:301 # l = 10 to 300
        F′ = F′[selection, selection]
        q′ = q′[selection]

        # Now compute the power spectrum and covariance
        M⁻¹  = BPJSpec.inverse_mixing_matrix(F′, strategy=:unwindowed)
        W    = BPJSpec.window_functions(F′, M⁻¹)
        Σ[β] = BPJSpec.windowed_covariance(F′[selection, selection], Minv)
        p[β] = M⁻¹ \ q′
    end
    p, Σ
end

end

