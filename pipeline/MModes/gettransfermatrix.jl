using PyPlot

function gettransfermatrix(spw, dataset, lmax)
    mmax = lmax
    dir = getdir(spw)
    ttcal_metadata = getmeta(spw, dataset)
    frame = TTCal.reference_frame(ttcal_metadata)
    β = round(Int, middle(1:Nfreq(ttcal_metadata)))
    ν = ttcal_metadata.channels[β:β]*u"Hz"

    # as a temporary hack, grab the beam model from the other directory
    coeff = load(joinpath(@__DIR__, "..", "..", "..", "mmode-analysis",
                          "workspace", "spw18", "beam.jld"),
                 "I-coeff")

    @time beam = create_beam_map(ttcal_metadata, coeff)
    @time bpjspec_metadata = BPJSpec.from_ttcal(frame, ttcal_metadata, lmax, mmax, ν, beam)

    #path = joinpath(dir, "transfermatrix-$lmax-$mmax")

    @time rhat = BPJSpec.unit_vectors(beam)
    @time plan = BPJSpec.plan_sht(lmax, mmax, size(beam))
    @time real_coeff, real_fringe = BPJSpec.fringe_pattern(bpjspec_metadata.baselines[2],#30741],
                                                          bpjspec_metadata.phase_center,
                                                          bpjspec_metadata.beam,
                                                          rhat, plan, ν[1])
    return real_coeff, real_fringe, plan

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

function create_beam_map(meta, coeff)
    frame = TTCal.reference_frame(meta)
    position = measure(frame, TTCal.position(meta), pos"ITRF")
    zenith = Direction(dir"ITRF", position.x, position.y, position.z) / radius(position)
    north  = Direction(dir"ITRF", 0.0, 0.0, 1.0)
    north  = north - dot(north, zenith)*zenith
    north  = north / radius(north)
    east   = cross(north, zenith)

    #map = BPJSpec.Map(zeros(5000, 8001))
    #map = BPJSpec.Map(zeros(1501, 3001))
    map = BPJSpec.Map(zeros(3001, 6001))
    for jdx = 1:size(map, 2), idx = 1:size(map, 1)
        vec = BPJSpec.index2vector(map, idx, jdx)
        el = π/2 - acos(clamp(dot(vec, zenith), -1, 1))
        x  = dot(vec, east)
        y  = dot(vec, north)
        az = atan2(x, y)
        ρ = cos(el)
        θ = az
        threshold = deg2rad(20) # soften the beam edge below this elevation
        if el < 0
            map[idx, jdx] = 0
        else
            beam = (coeff[1]*TTCal.zernike(0, 0, ρ, θ)
                  + coeff[2]*TTCal.zernike(2, 0, ρ, θ)
                  + coeff[3]*TTCal.zernike(4, 0, ρ, θ)
                  + coeff[4]*TTCal.zernike(4, 4, ρ, θ)
                  + coeff[5]*TTCal.zernike(6, 0, ρ, θ)
                  + coeff[6]*TTCal.zernike(6, 4, ρ, θ)
                  + coeff[7]*TTCal.zernike(8, 0, ρ, θ)
                  + coeff[8]*TTCal.zernike(8, 4, ρ, θ)
                  + coeff[9]*TTCal.zernike(8, 8, ρ, θ))
            #if el < threshold
            #    # Shaping function from http://www.flong.com/texts/code/shapers_poly/
            #    shape = 4/9*(el/threshold)^6 - 17/9*(el/threshold)^4 + 22/9*(el/threshold)^2
            #    map[idx, jdx] = beam*shape
            #else
                map[idx, jdx] = beam
            #end
        end
    end
    map
end

