module Driver

using BPJSpec
using Unitful

include("../lib/Common.jl"); using .Common

function compress(spw, name)
    path = getdir(spw, name)

    file = joinpath(path, "transfer-matrix")
    transfermatrix = HierarchicalTransferMatrix(file)
    lmax = BPJSpec.getlmax(transfermatrix)
    mmax = lmax
    frequencies = transfermatrix.metadata.frequencies

    file = joinpath(path, "noise-matrix")
    noise = BPJSpec.NoiseModel(10000u"K", 24u"kHz", 13u"s", 7756,
                               BPJSpec.gethierarchy(transfermatrix))
    noisematrix = NoiseMatrix(file, mmax, frequencies, noise)
    #noisematrix = NoiseMatrix(file)

    transfermatrix′, noisematrix′ = BPJSpec.full_rank_compress(transfermatrix, noisematrix)
    #file = joinpath(path, "transfer-matrix-compressed")
    #transfermatrix′ = SpectralBlockDiagonalMatrix(file)
    #file = joinpath(path, "noise-matrix-compressed")
    #noisematrix′ = SpectralBlockDiagonalMatrix(file)

    # According to this calculation, averaging 10 channels should limit us to k < 1.0 Mpc^-1, which
    # is fine:
    # julia> 2π/(comoving_distance(redshift(70.000u"MHz"))-comoving_distance(redshift(70.240u"MHz")))
    # 1.0273400427793544 Mpc^-1
    transfermatrix″, noisematrix″ = BPJSpec.average_channels(transfermatrix′, noisematrix′, 10)
end

end

