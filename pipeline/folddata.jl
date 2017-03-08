function fold(spw, target="peeled-visibilities")
    dir = getdir(spw)
    data, flags = load(joinpath(dir, target*".jld"), "data", "flags")
    fold(spw, data, flags, target)
end

function fold(spw, data, flags, target)
    _, Nbase, Ntime = size(data)
    sidereal_day = 6628 # number of integrations in one sidereal day
    normalization = zeros(Int, Nbase, sidereal_day)
    output_data = zeros(Complex128, Nbase, sidereal_day)
    output_flags = trues(Nbase, sidereal_day)
    flags = apply_special_case_flags(spw, flags)
    for idx = 1:Ntime, α = 1:Nbase
        if !flags[α, idx]
            jdx = mod1(idx, sidereal_day)
            stokesI = 0.5*(data[1, α, idx] + data[2, α, idx])
            normalization[α, jdx] += 1
            output_data[α, jdx] += stokesI
            output_flags[α, jdx] = false
        end
    end
    for jdx = 1:sidereal_day, α = 1:Nbase
        if normalization[α, jdx] != 0
            output_data[α, jdx] /= normalization[α, jdx]
        end
    end
    save(joinpath(getdir(spw), "folded-$target.jld"),
         "data", output_data, "flags", output_flags, compress=true)
    output_data, output_flags
end

function apply_special_case_flags(spw, flags)
    myflags = copy(flags)
    if spw == 18
        myflags[:, 8590] = true # peeling failure associated with Vir A
    end
    myflags
end

