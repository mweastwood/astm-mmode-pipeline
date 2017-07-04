function verify_beam(spw)
    dir = getdir(spw)
    names, fluxes, coeff_I, coeff_Q, image_I, image_Q, I, Q, l, m =
        load(joinpath(dir, "beam.jld"), "sources", "fluxes", "I-coeff", "Q-coeff",
             "I-image", "Q-image", "I", "Q", "l", "m")
    N = length(names)

    # Image of the I beam with source tracks
    figure(1); clf()
    circle = plt[:Circle]((0, 0), 1, alpha=0)
    gca()[:add_patch](circle)
    imshow(image_I.', extent=(-1, 1, -1, 1), interpolation="nearest", vmin=0, vmax=1,
           cmap=get_cmap("magma"), clip_path=circle)
    for s = 1:N
        scatter(l[s], m[s], c=(I[s]/fluxes[s]), vmin=0, vmax=1, cmap=get_cmap("magma"))
    end
    gca()[:set_aspect]("equal")
    colorbar()
    xlim(-1, 1)
    ylim(-1, 1)
    tight_layout()

    # Image of the Q beam with source tracks
    figure(2); clf()
    circle = plt[:Circle]((0, 0), 1, alpha=0)
    gca()[:add_patch](circle)
    imshow(image_Q.', extent=(-1, 1, -1, 1), interpolation="nearest", vmin=-0.25, vmax=0.25,
           cmap=get_cmap("magma"), clip_path=circle)
    for s = 1:N
        scatter(l[s], m[s], c=(Q[s]/fluxes[s]), vmin=-0.25, vmax=0.25, cmap=get_cmap("magma"))
    end
    gca()[:set_aspect]("equal")
    colorbar()
    xlim(-1, 1)
    ylim(-1, 1)
    tight_layout()

    # Predicted versus measured fluxes
    for s = 1:N
        figure(s+2); clf()
        plot(I[s], "k.")
        expected = Float64[]
        for (l_, m_) in zip(l[s], m[s])
            ρ_ = hypot(l_, m_)
            θ_ = atan2(l_, m_)
            beam = (coeff_I[1]*TTCal.zernike(0, 0, ρ_, θ_)
                        + coeff_I[2]*TTCal.zernike(2, 0, ρ_, θ_)
                        + coeff_I[3]*TTCal.zernike(4, 0, ρ_, θ_)
                        + coeff_I[4]*TTCal.zernike(4, 4, ρ_, θ_)
                        + coeff_I[5]*TTCal.zernike(6, 0, ρ_, θ_)
                        + coeff_I[6]*TTCal.zernike(6, 4, ρ_, θ_)
                        + coeff_I[7]*TTCal.zernike(8, 0, ρ_, θ_)
                        + coeff_I[8]*TTCal.zernike(8, 4, ρ_, θ_)
                        + coeff_I[9]*TTCal.zernike(8, 8, ρ_, θ_))
            push!(expected, beam*fluxes[s])
        end
        plot(expected, "r.")
        title(names[s])
    end
end

