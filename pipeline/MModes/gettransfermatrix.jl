using PyPlot

function gettransfermatrix(spw, dataset)
    dir = getdir(spw)
    ttcal_metadata = getmeta(spw, dataset)
    bpjspec_metadata = BPJSpec.from_ttcal(ttcal_metadata)

    coeff = load("/lustre/mweastwood/mmode-analysis/workspace/spw18/beam.jld", "I-coeff")
    threshold = deg2rad(10)
    function beam_model(azimuth, elevation)
        beam(coeff, threshold, azimuth, elevation)
    end

    lmax, divisions, categories, cumulative_space = BPJSpec.baseline_hierarchy(bpjspec_metadata)

    figure(3); clf()
    plot(cumulative_space, "k.")

    total = 0.0
    for idx = 1:length(divisions)-1
        lmax_ = divisions[idx+1]
        Nbase = sum(categories .== idx)
        space = Nbase*lmax_*lmax_*128/(8*1024^3)
        total += space
        @show lmax_, space
    end
    @show total

    figure(1); clf()
    for idx = 1:length(divisions-1)
        plot(lmax[categories .== idx], ".")
    end
    for division in divisions
        axhline(division)
    end

    figure(2); clf()
    plt[:hist](lmax, bins=100)
    for division in divisions
        axvline(division, color="k")
    end
    xlabel("lmax")
    ylabel("number of baselines")

    #@time map = BPJSpec.create_beam_map(beam_model, bpjspec_metadata, (2001, 4001))

    #figure(1); clf()
    #imshow(map)
    #colorbar()

    #frame = TTCal.reference_frame(ttcal_metadata)
    #β = round(Int, middle(1:Nfreq(ttcal_metadata)))
    #ν = ttcal_metadata.channels[β:β]*u"Hz"


    #@time beam = create_beam_map(ttcal_metadata, coeff)
    #@time bpjspec_metadata = BPJSpec.from_ttcal(frame, ttcal_metadata, lmax, mmax, ν, beam)

    #@show BPJSpec.baseline_hierarchy(bpjspec_metadata)

    #path = joinpath(dir, "transfermatrix-$lmax-$mmax")

    #@time rhat = BPJSpec.unit_vectors(beam)
    #@time plan = BPJSpec.plan_sht(lmax, mmax, size(beam))
    #@time real_coeff, real_fringe = BPJSpec.fringe_pattern(bpjspec_metadata.baselines[2],#30741],
    #                                                      bpjspec_metadata.phase_center,
    #                                                      bpjspec_metadata.beam,
    #                                                      rhat, plan, ν[1])
    #return real_coeff, real_fringe, plan

    #figure(1); clf()
    ##subplot(1, 2, 1)
    #imshow(abs.(real_coeff.matrix))
    #gca()[:set_aspect]("auto")
    #colorbar()
    ##subplot(1, 2, 2)
    ##imshow(abs.(imag_coeff.matrix))
    ##gca()[:set_aspect]("auto")
    ##colorbar()
    #tight_layout()

    #figure(1); clf()
    #subplot(2, 1, 1)
    #imshow(real_coeff)
    #colorbar()
    #subplot(2, 1, 2)
    #imshow(imag_coeff)
    #colorbar()

    # TEST
    #variables = BPJSpec.TransferMatrixVariables(meta, lmax, mmax, nside)
    #α = 30741
    #return @time BPJSpec.fringes(beam, variables, meta.channels[1], α)
    # TEST
    #transfermatrix = TransferMatrix(path, meta, beam, lmax, mmax, nside)
end

function beam(coeff, threshold, azimuth, elevation)
    elevation < 0 && return 0.0
    ρ = cos(elevation)
    θ = azimuth
    amplitude = (coeff[1]*TTCal.zernike(0, 0, ρ, θ)
                + coeff[2]*TTCal.zernike(2, 0, ρ, θ)
                + coeff[3]*TTCal.zernike(4, 0, ρ, θ)
                + coeff[4]*TTCal.zernike(4, 4, ρ, θ)
                + coeff[5]*TTCal.zernike(6, 0, ρ, θ)
                + coeff[6]*TTCal.zernike(6, 4, ρ, θ)
                + coeff[7]*TTCal.zernike(8, 0, ρ, θ)
                + coeff[8]*TTCal.zernike(8, 4, ρ, θ)
                + coeff[9]*TTCal.zernike(8, 8, ρ, θ))
    if elevation < threshold
        # Shaping function from http://www.flong.com/texts/code/shapers_poly/
        x = elevation/threshold
        shape = 4/9*x^6 - 17/9*x^4 + 22/9*x^2
        amplitude *= shape
    end
    amplitude
end

