module Driver

using ProgressMeter
using HDF5, JLD

using TTCal
using MLPFlagger
using BPJSpec

using CasaCore.Tables
using LibHealpix

const dir = "/lustre/data/2015-03-27_ten_day_run/06"
const files = readdir(dir)

# filter the list of files down to the desired run
filter!(files) do file
    startswith(file,"2015-03-29-06:04:01")
end

# keep only the first day's worth of data
deleteat!(files,2881:length(files))

function getcal()
    if !isdir("cal.ms")
        data = joinpath(dir,files[1250])
        run(`dada2ms $data cal.ms`)
    end

    ms = MeasurementSet("cal.ms")
    sources = readsources("sources.json")
    beam = TTCal.SineBeam()

    # flag bad antennas
    clearflags!(ms)
    flags = low_power_antennas(ms)
    flags[247:256,:] = true
    flags[90,2] = true
    flags[92,2] = true
    @show flags
    applyflags!(ms,flags)

    # flag bright rfi
    flags = bright_narrow_rfi(ms)
    applyflags!(ms,flags)

    # calibrate
    cal = gaincal(ms,sources,beam,maxiter=20,tolerance=1e-3)
    #flags = MLPFlagger.nonlinear_phase(cal)
    #applyflags!(cal,flags)
    applycal!(ms,cal,force_imaging_columns=true)

    TTCal.write("cal.jld",cal)
    unlock(ms)
    nothing
end

function getdata()
    range = 1:2:length(files)

    ms = MeasurementSet("cal.ms")
    Nbase = div(ms.Nant*(ms.Nant-1),2)
    Ntime = length(range)
    frequencies = ms.ν
    unlock(ms)

    cal = TTCal.read("cal.jld")
    isfile("visibilities.jld") && rm("visibilities.jld")
    create_empty_visibilities("visibilities.jld", Nbase, Ntime, frequencies)
    @showprogress 1 "Gridding data..." for i in range
        getdata(i,cal)
    end
end

function getdata(integration,calibration)
    isfile("cal.jld") || error("run getcal() first")

    _dada = files[integration]
    _ms   = "mwe_"*replace(_dada,"dada","ms")

    dada = joinpath(dir,_dada)
    path = joinpath("/dev/shm",_ms) |> ascii
    run(`dada2ms $dada $path`)

    ms = MeasurementSet(path)
    applycal!(ms,calibration)
    grid_visibilities("visibilities.jld", ms)

    unlock(ms)
    rm(path,recursive=true)
    nothing
end

function gettransfer(channel::Int)
    lmax = mmax = 200
    ms = MeasurementSet("workspace/cal.ms")
    ν  = ms.ν[channel]
    transfermatrix = transfer(ms, SineBeam(), channel; lmax=lmax, mmax=mmax)
    @time legacy_save_transfermatrix("full_transfermatrix.jld", transfermatrix)
    unlock(ms)
end

function gettransfer(range)
    for i in range
        @show i
        @show now()
        gettransfer(i)
        @show now()
        @everywhere gc()
    end
end

function compress(channel::Int)
    lmax = mmax = 200
    ms = MeasurementSet("workspace/cal.ms")
    ν  = ms.ν[channel]
    unlock(ms)

    # system temperature sourced from http://www.phys.unm.edu/~lwa/obsstatus/obsstatus006.html
    # total integration time is ~12 hours in 30 second integrations (every other integration)
    noise_model = NoiseModel(6420,2.56,45e6,24e3,12*3600.0,30.0)

    @time B = legacy_load_transfermatrix("workspace/full_transfermatrix_ten_channels.jld",ν)
    @time visibilities = load_visibilities("workspace/visibilities.jld",ν)
    @time v = mmodes(visibilities,mmax=mmax,frequency=ν)
    @time N = covariance_matrix(noise_model, v)

    @time P = preserve_singular_values(B)
    @time newB = P*B
    @time newv = P*v
    @time newN = P*N*P'

    @time BPJSpec.save("workspace/compressed_transfermatrix_ten_channels.jld",newB)
    @time BPJSpec.save("workspace/compressed_mmodes_ten_channels.jld",newv)
    @time BPJSpec.save("workspace/compressed_noise_ten_channels.jld",newN)
end

function compress(range)
    for i in range
        @show i
        @show now()
        compress(i)
        @show now()
        gc()
    end
end

function image(channel::Int)
    lmax = mmax = 200
    ms = MeasurementSet("workspace/cal.ms")
    ν  = ms.ν[channel]
    unlock(ms)

    @time B = BPJSpec.load("workspace/compressed_transfermatrix_ten_channels.jld",lmax,mmax,ν)
    @time v = BPJSpec.load("workspace/compressed_mmodes_ten_channels.jld",mmax,ν)

    @time alm = tikhonov(B,v,tolerance=5e-1)
    @time map = alm2map(alm,nside=512)
    JLD.save("workspace/image.jld","img",mollweide(map))
end

function model()
    lmax = mmax = 200
    ms = MeasurementSet("workspace/cal.ms")
    ν  = 45.708e6
    #ν  = ms.ν[channel] # commented because I'm currently adding 1e3 here
    t  = BPJSpec.sidereal_time(ms)

    #ms.table["BACKUP_DATA"] = ms.table["CORRECTED_DATA"]
    ms.table["CORRECTED_DATA"] = ms.table["BACKUP_DATA"]

    @time B    = legacy_load_transfermatrix("workspace/full_transfermatrix.jld",ν)
    @time vis = load_visibilities("workspace/visibilities.jld",ν)
    @time v   = mmodes(vis,mmax=mmax,frequency=ν)
    @time alm = tikhonov(B,v,tolerance=5e-1)
    @time map = alm2map(alm,nside=512)
    @time v   = B * alm
    @time vis = visibilities(v)

    Ntime = size(vis,2)
    Δt = 1/Ntime
    grid = 0.0:Δt:(1.0-Δt)
    idx1 = searchsortedlast(grid,t)
    idx2 = idx1 == Ntime? 1 : idx1+1
    weight1 = 1 - abs(t - grid[idx1])/Δt
    weight2 = 1 - abs(t - grid[idx2])/Δt
    model = weight1 * vis[:,idx1] + weight2 * vis[:,idx2]

    # now let's make sure to add the auto correlations back int
    data = ms.table["CORRECTED_DATA"]
    model_with_autos = zeros(Complex128, ms.Nbase)
    idx = 1
    for α = 1:ms.Nbase
        ms.ant1[α] == ms.ant2[α] && continue
        model_with_autos[α] = model[idx]
        idx += 1
    end
    full_model = zeros(Complex64, size(data))
    full_model[1,1,:] = model_with_autos
    full_model[4,1,:] = model_with_autos

    data[1,2:end,:] = 0
    data[2,:,:] = 0
    data[3,:,:] = 0
    data[4,2:end,:] = 0

    ms.table["MMODE_MODEL_DATA"] = full_model
    ms.table["CORRECTED_DATA"] = full_model#data - full_model

    unlock(ms)
    #JLD.save("workspace/image.jld","img",mollweide(map))
end

function recall()
    ms = MeasurementSet("workspace/cal.ms")
    data = ms.table["BACKUP_DATA"]
    data[1,2:end,:] = 0
    data[2,:,:] = 0
    data[3,:,:] = 0
    data[4,2:end,:] = 0
    model = ms.table["MMODE_MODEL_DATA"]
    ms.table["CORRECTED_DATA"] = data - model
    unlock(ms)
end

##################################

function check_if_interpolation_is_valid()
    lmax = mmax = 200
    ms = MeasurementSet("workspace/cal.ms")
    unlock(ms)

    blocks = Matrix{Complex128}[]
    for channel = 1:109
        @show channel
        ν = ms.ν[channel]
        @time B = legacy_load_transfermatrix("workspace/full_transfermatrix.jld",ν)
        push!(blocks,B[1].block)
        finalize(B)
    end

    JLD.save("test_blocks.jld","blocks",blocks)
end

function legacy_save_transfermatrix(filename,B)
    jldopen(filename,"r+",compress=true) do file
        ν = B.meta.ν[1]
        name_ν  = @sprintf("%.3fMHz",ν/1e6)
        name_ν in names(file) && error("group $(name_ν) already exists in file")
        group_ν = g_create(file,name_ν)

        for m = 0:BPJSpec.mmax(B)
            group_m = g_create(group_ν,string(m))
            group_m["block"] = B[m+1].block
        end
    end
end

function legacy_load_transfermatrix(filename,ν)
    local lmax,mmax
    blocks = BPJSpec.MatrixBlock[]
    jldopen(filename,"r") do file
        lmax = file["lmax"] |> read
        mmax = file["mmax"] |> read

        name_ν  = @sprintf("%.3fMHz",ν/1e6)
        group_ν = file[name_ν]

        for m = 0:mmax
            group_m = group_ν[string(m)]
            block = group_m["block"] |> read
            push!(blocks,BPJSpec.MatrixBlock(block))
        end
    end
    meta = BPJSpec.TransferMeta(lmax,mmax,ν)
    BPJSpec.TransferMatrix(blocks,meta)
end

end

