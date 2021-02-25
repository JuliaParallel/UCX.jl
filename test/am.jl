using Distributed
using Test

addprocs(1)

# @everywhere begin
#     using Pkg
#     Pkg.activate(@__DIR__)
# end

@everywhere using UCX

@everywhere begin

const times = Channel{Int}()

const AM_RECEIVE = 1
const AM_ANSWER = 2

function am_receive(worker, header, header_length, data, length, _param)
    param = Base.unsafe_load(_param)::UCX.API.ucp_am_recv_param_t
    # @assert (param.recv_attr & UCX.API.UCP_AM_RECV_ATTR_FIELD_REPLY_EP) != 0
    # ep = UCX.UCXEndpoint(worker, param.reply_ep)

    @assert header_length == sizeof(Int)
    id = Base.unsafe_load(Base.unsafe_convert(Ptr{Int}, header))

    UCX.@async_showerr begin
        ep = proc_to_endpoint(1)
        header = Ref{Int}(id)
        req = UCX.am_send(ep, AM_ANSWER, header)
        wait(req)
    end
    return UCX.API.UCS_OK
end

function am_answer(worker, header, header_length, data, length, param)
    @assert header_length == sizeof(Int)
    id = Base.unsafe_load(Base.unsafe_convert(Ptr{Int}, header))
    UCX.@async_showerr put!(times, id)
    return UCX.API.UCS_OK
end

function start()
    ctx = UCX.UCXContext()
    worker = UCX.UCXWorker(ctx)

    UCX.AMHandler(worker, am_receive, AM_RECEIVE) 
    UCX.AMHandler(worker, am_answer,  AM_ANSWER) 

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

wakeup() = notify(UCX_WORKER)

end # @everywhere

wireup()
const header = Ref{Int}(0)

function send()
    ep =proc_to_endpoint(2)

    id = header[]
    time_start = Base.time_ns()
    UCX.fence(ep.worker)
    # req = UCX.am_send(ep, AM_RECEIVE, header, nothing, UCX.API.UCP_AM_SEND_FLAG_REPLY)
    req = UCX.am_send(ep, AM_RECEIVE, header)
    wait(req)
    header[] += 1
    oid = take!(times)
    time_end = Base.time_ns()
    @assert oid == id
    time_end - time_start
end

function bench(n)
    start_times = UInt64[]
    for i in 1:n
        push!(start_times, send())
    end
    start_times
end
