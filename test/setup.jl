using Distributed

addprocs(1)

@everywhere using UCX

@everywhere begin

function start()
    ctx = UCX.UCXContext()
    worker = UCX.UCXWorker(ctx)

    global UCX_WORKER = worker
    atexit() do
        close(worker)
    end

    UCX.@spawn_showerr begin
        while isopen(worker)
            wait(worker)
        end
        close(worker)
    end

    addr = UCX.UCXAddress(worker)
    GC.@preserve addr begin
        ptr = Base.unsafe_convert(Ptr{UInt8}, addr.handle)
        addr_buf = Base.unsafe_wrap(Array, ptr, addr.len; own=false)
        bind_addr = similar(addr_buf)
        copyto!(bind_addr, addr_buf)
    end

    return bind_addr
end

const UCX_PROC_ENDPOINT = Dict{Int, UCX.UCXEndpoint}()
const UCX_ADDR_LISTING  = Dict{Int, Vector{UInt8}}()

function wireup(procs=Distributed.procs())
    # Ideally we would use FluxRM or PMI and use their
    # distributed KVS.
    ucx_addr = Dict{Int, Vector{UInt8}}()
    @sync for p in procs
        @async begin
            ucx_addr[p] = Distributed.remotecall_fetch(start, p)
        end
    end

    @sync for p in procs
        @async begin
            Distributed.remotecall_wait(p, ucx_addr) do ucx_addr
                merge!(UCX_ADDR_LISTING, ucx_addr)
            end
        end
    end
end

function proc_to_endpoint(p)
    get!(UCX_PROC_ENDPOINT, p) do
        worker = UCX_WORKER::UCX.UCXWorker
        UCX.UCXEndpoint(worker, UCX_ADDR_LISTING[p])
    end
end

end # @everywhere

wireup()