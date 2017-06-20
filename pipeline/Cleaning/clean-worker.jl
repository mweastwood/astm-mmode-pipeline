immutable CleanWorkerPool
    observation_matrix_workers :: Vector{Int}
    spherical_harmonic_workers :: Vector{Int}
    spherical_harmonic_transform_workers :: Vector{Int}
end

immutable CleanWorkerIO
    observation_matrix_worker_input :: Vector{RemoteChannel}
    observation_matrix_worker_output :: Vector{RemoteChannel}
end

function classify_workers(spws = 4:2:18)
    N = length(spws)
    gethostname() = chomp(readstring(`hostname`))
    myhostname = gethostname()
    futures   = [remotecall(gethostname, worker) for worker in workers()]
    hostnames = [fetch(future) for future in futures]
    unique_hostnames = unique(hostnames)

    observation_matrix_workers = Int[]
    spherical_harmonic_workers = collect(workers())
    spherical_harmonic_transform_workers = Int[]

    # use local workers for doing the spherical harmonic transforms
    for hostname in repeated(myhostname)
        length(spherical_harmonic_transform_workers) < N || break
        idx = first(find(hostnames .== hostname))
        worker = spherical_harmonic_workers[idx]
        push!(spherical_harmonic_transform_workers, worker)
        deleteat!(spherical_harmonic_workers, idx)
        deleteat!(hostnames, idx)
    end

    # use a distributed group of remote workers for multiplying by the observation matrix
    for hostname in cycle(unique_hostnames)
        length(observation_matrix_workers) < N || break
        any(hostnames .== hostname) || continue
        idx = first(find(hostnames .== hostname))
        worker = spherical_harmonic_workers[idx]
        push!(observation_matrix_workers, worker)
        deleteat!(spherical_harmonic_workers, idx)
        deleteat!(hostnames, idx)
    end

    CleanWorkerPool(observation_matrix_workers,
                    spherical_harmonic_workers,
                    spherical_harmonic_transform_workers)
end

function close_worker_io(io)
    foreach(close, io.observation_matrix_worker_input)
    foreach(close, io.observation_matrix_worker_output)
end

function start_workers(pool, spws, dataset)
    N = length(pool.observation_matrix_workers)
    observation_matrix_worker_input  = [RemoteChannel() for idx = 1:N]
    observation_matrix_worker_output = [RemoteChannel() for idx = 1:N]
    for idx = 1:N
        worker = pool.observation_matrix_workers[idx]
        remotecall(observation_matrix_worker_loop, worker, spws[idx], dataset,
                   observation_matrix_worker_input[idx], observation_matrix_worker_output[idx])
    end
    CleanWorkerIO(observation_matrix_worker_input, observation_matrix_worker_output)
end

function observation_matrix_worker_loop(spw, dataset, input, output)
    dir = getdir(spw)
    observation_matrix = load(joinpath(dir, "observation-matrix-$dataset.jld"), "blocks")
    while true
        input_alm = take!(input)
        output_alm = observe(observation_matrix, input_alm)
        put!(output, output_alm)
    end
end

function observe(observation_matrix, input_alm)
    output_alm = Alm(Complex128, lmax(input_alm), mmax(input_alm))
    for m = 0:mmax(input_alm)
        A = observation_matrix[m+1]
        x = [input_alm[l, m] for l = m:lmax(input_alm)]
        y = A*x
        for l = m:lmax(input_alm)
            output_alm[l, m] = y[l-m+1]
        end
    end
    output_alm
end

