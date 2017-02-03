"Image after integrating over the entire data set."
function integrate(spw; input="visibilities", output="integrated")
    Lumberjack.info("Integrating over the entire data set for spectral window $spw")
    dir = getdir(spw)

    path_to_visibilities = joinpath(dir, input)
    visibilities = GriddedVisibilities(path_to_visibilities)[1]
    integrated = sum(visibilities, 2)

    ms, path = create_template_ms(spw, output*".ms")
    write_to_ms!(spw, ms, integrated)
    finalize(ms)
    wsclean(path, weight="natural")

    nothing
end

function create_template_ms(spw, name)
    dir = getdir(spw)
    name = joinpath(dir, name)
    dada = listdadas(spw)[4000]
    dada2ms_core(dada, name)
    Table(ascii(name)), name
end

function write_to_ms!(spw, ms, integrated)
    meta = getmeta(spw)
    β = round(Int, middle(1:Nfreq(meta)))
    output = zeros(Complex64, 4, Nfreq(meta), Nbase(meta))
    for α = 1:Nbase(meta)
        output[1,β,α] = integrated[α]
        output[4,β,α] = integrated[α]
    end
    ms["DATA"] = output
end

