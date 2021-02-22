module Legacy

#=
md"""
# The nature of a `remotecall`

1. Sender:
  - remotecall
    - `AMHeader` --> Ref (heap allocated)
    - `msg` --> serialized into IOBuffer :/
2. Receiver:
  - AMHandler
    - ccall to `am_recv_callback`
    - dynamic call to `AMHandler.func` :/ -- can we precompute this -- FunctionWrapper.jl
    - `AMHandler.func` == `am_remotecall`
       Check: `code_typed(UCX.Legacy.am_remotecall, (Ptr{Cvoid}, Csize_t, Ptr{Cvoid}, Csize_t, Ptr{UCX.API.ucp_am_recv_param_t}))`
      - `deserialize()::Distributed.CallMsg{:call}`
    - handle_msg -> creates closure... :/
    - call to `schedule_call`
      - creates closure + task (@async)
"""
=#

import ..UCX
import Distributed

struct AMHeader
    from::Int
    hdr::Distributed.MsgHeader
end

function handle_msg(msg::Distributed.CallMsg{:call}, header)
    Distributed.schedule_call(header.response_oid, ()->msg.f(msg.args...; msg.kwargs...))
end

function handle_msg(msg::Distributed.CallMsg{:call_fetch}, header)
    UCX.@async_showerr begin
        v = Distributed.run_work_thunk(()->msg.f(msg.args...; msg.kwargs...), false)
        if isa(v, Distributed.SyncTake)
            try
                req = deliver_result(:call_fetch, header.notify_oid, v)
            finally
                unlock(v.rv.synctake)
            end
        else
            req = deliver_result(:call_fetch, header.notify_oid, v)
        end
        if @isdefined(req)
            wait(req)
        end
    end
end

function handle_msg(msg::Distributed.CallWaitMsg, header)
    UCX.@async_showerr begin
        rv = Distributed.schedule_call(header.response_oid, ()->msg.f(msg.args...; msg.kwargs...))
        req = deliver_result(:call_wait, header.notify_oid, fetch(rv.c))
        wait(req)
    end
end

function handle_msg(msg::Distributed.RemoteDoMsg, header)
    UCX.@async_showerr begin
        Distributed.run_work_thunk(()->msg.f(msg.args...; msg.kwargs...), true)
    end
end

function handle_msg(msg::Distributed.ResultMsg, header)
    put!(Distributed.lookup_ref(header.response_oid), msg.value)
end

@inline function am_handler(::Type{Msg}, worker, header, header_length, data, length, _param) where Msg
    @assert header_length == sizeof(AMHeader)
    phdr = Base.unsafe_convert(Ptr{AMHeader}, header)
    am_hdr = Base.unsafe_load(phdr)

    param = Base.unsafe_load(_param)::UCX.API.ucp_am_recv_param_t
    if (param.recv_attr & UCX.API.UCP_AM_RECV_ATTR_FLAG_RNDV) == 0
        if true
            ptr = Base.unsafe_convert(Ptr{UInt8}, data)
            buf = IOBuffer(Base.unsafe_wrap(Array, ptr, length))

            msg = lock(proc_to_serializer(am_hdr.from)) do serializer
                prev_io = serializer.io
                serializer.io = buf
                msg = Distributed.deserialize_msg(serializer)::Msg
                serializer.io = prev_io 
                msg
            end

            handle_msg(msg, am_hdr.hdr)
            return UCX.API.UCS_OK
        else
            UCX.@async_showerr begin
                ptr = Base.unsafe_convert(Ptr{UInt8}, data)
                buf = IOBuffer(Base.unsafe_wrap(Array, ptr, length))

                # We could do this asynchronous
                # Would need to return `IN_PROGRESS` and use UCX.am_data_release
                msg = lock(proc_to_serializer(am_hdr.from)) do serializer
                    prev_io = serializer.io
                    serializer.io = buf
                    msg = Distributed.deserialize_msg(serializer)::Msg
                    serializer.io = prev_io 
                    msg
                end
                UCX.am_data_release(worker, data)

                handle_msg(msg, am_hdr.hdr)
            end
            return UCX.API.UCS_INPROGRESS
        end
    else
        @assert (param.recv_attr & UCX.API.UCP_AM_RECV_ATTR_FLAG_RNDV) != 0
        UCX.@async_showerr begin
            # Allocate rendezvous buffer
            # XXX: Support CuArray etc.
            buffer = Array{UInt8}(undef, length)
            req = UCX.am_recv(worker, data, buffer, length)
            wait(req)
            # UCX.am_data_release not necessary due to am_recv

            buf = IOBuffer(buffer)
            peer_id = am_hdr.from 
            msg = lock(proc_to_serializer(am_hdr.from)) do serializer
                prev_io = serializer.io
                serializer.io = buf
                msg = Base.invokelatest(Distributed.deserialize_msg, serializer)::Msg
                serializer.io = prev_io 
                msg
            end

            handle_msg(msg, am_hdr.hdr)
        end
        return UCX.API.UCS_INPROGRESS
    end
end

const AM_REMOTECALL = 1
function am_remotecall(worker, header, header_length, data, length, param)
    am_handler(Distributed.CallMsg{:call}, worker, header, header_length, data, length, param)
end

const AM_REMOTECALL_FETCH = 2
function am_remotecall_fetch(worker, header, header_length, data, length, param)
    am_handler(Distributed.CallMsg{:call_fetch}, worker, header, header_length, data, length, param)
end

const AM_REMOTECALL_WAIT = 3
function am_remotecall_wait(worker, header, header_length, data, length, param)
    am_handler(Distributed.CallWaitMsg, worker, header, header_length, data, length, param)
end

const AM_REMOTE_DO = 4
function am_remote_do(worker, header, header_length, data, length, param)
    am_handler(Distributed.RemoteDoMsg, worker, header, header_length, data, length, param)
end

const AM_RESULT = 5
function am_result(worker, header, header_length, data, length, param)
    am_handler(Distributed.ResultMsg, worker, header, header_length, data, length, param)
end

function start()
    ctx = UCX.UCXContext()
    worker = UCX.UCXWorker(ctx)

    UCX.AMHandler(worker, am_remotecall,       AM_REMOTECALL) 
    UCX.AMHandler(worker, am_remotecall_fetch, AM_REMOTECALL_FETCH) 
    UCX.AMHandler(worker, am_remotecall_wait,  AM_REMOTECALL_WAIT)
    UCX.AMHandler(worker, am_remote_do,        AM_REMOTE_DO)
    UCX.AMHandler(worker, am_result,           AM_RESULT)

    global UCX_WORKER = worker
    atexit() do
        close(worker)
    end

    @async begin
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

struct UCXSerializer
    serializer::Distributed.ClusterSerializer{Base.GenericIOBuffer{Array{UInt8,1}}}
    lock::Base.ReentrantLock
end
function Base.lock(f, ucx::UCXSerializer)
    lock(ucx.lock) do
        f(ucx.serializer)
    end
end

const UCX_PROC_ENDPOINT = Dict{Int, UCX.UCXEndpoint}()
const UCX_ADDR_LISTING  = Dict{Int, Vector{UInt8}}()
const UCX_SERIALIZERS = Dict{Int, UCXSerializer}()

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

function proc_to_serializer(p)
    this = get!(UCX_SERIALIZERS, p) do
        cs = Distributed.ClusterSerializer(IOBuffer())
        cs.pid = p
        UCXSerializer(cs, Base.ReentrantLock())
    end
end


function send_msg(pid, hdr, msg, id)
    ep = proc_to_endpoint(pid)
    data = lock(proc_to_serializer(pid)) do serializer
        Base.invokelatest(Distributed.serialize_msg, serializer, msg)
        take!(serializer.io)
    end

    header = Ref(hdr)

    req = UCX.am_send(ep, id, header, data)
    UCX.fence(ep.worker) # Gurantuee order
    req
end

abstract type UCXRemoteRef <: Distributed.AbstractRemoteRef end

function Distributed.call_on_owner(f, rr::UCXRemoteRef, args...)
    rid = Distributed.remoteref_id(rr)
    remotecall_fetch(f, rr.rr.where, rid, args...)
end

struct UCXFuture <:UCXRemoteRef
    rr::Distributed.Future
end
Distributed.remoteref_id(rr::UCXFuture) = Distributed.remoteref_id(rr.rr)

function Distributed.fetch(ur::UCXFuture)
    r = ur.rr
    r.v !== nothing && return something(r.v)
    v = Distributed.call_on_owner(Distributed.fetch_ref, ur)
    r.v = Some(v)
    Distributed.send_del_client(r)
    v
end

function Distributed.isready(ur::UCXFuture)
    rr = ur.rr
    rr.v === nothing || return true

    rid = remoteref_id(rr)
    return if rr.where == myid()
        isready(Distributed.lookup_ref(rid).c)
    else
        remotecall_fetch(rid->isready(Distributed.lookup_ref(rid).c), rr.where, rid)
    end
end

function Distributed.wait(ur::UCXFuture)
    r = ur.rr
    if r.v !== nothing
        return ur
    else
        Distributed.call_on_owner(Distributed.wait_ref, ur, Distributed.myid())
        return ur
    end
end

function Distributed.put!(ur::UCXFuture, v)
    rr = ur.rr
    rr.v !== nothing && error("Future can be set only once")
    call_on_owner(put_future, ur, v, myid())
    rr.v = Some(v)
    ur
end

# struct UCXRemoteChannel{RC<:Distributed.RemoteChannel} <: Distributed.AbstractRemoteRef
#     rc::RC
# end
# Distributed.remoteref_id(rr::UCXRemoteChannel) = Distributed.remoteref_id(rr.rc)
# Base.eltype(::Type{UCXRemoteChannel{RC}}) where {RC} = eltype(RC)

function remotecall(f, pid, args...; kwargs...)
    rr = Distributed.Future(pid)

    hdr = Distributed.MsgHeader(Distributed.remoteref_id(rr))
    header = AMHeader(Distributed.myid(), hdr)
    msg = Distributed.CallMsg{:call}(f, args, kwargs)

    req = send_msg(pid, header, msg, AM_REMOTECALL)
    # XXX: ensure that req is making progress
    UCXFuture(rr)
end

function remotecall_fetch(f, pid, args...; kwargs...)
    oid = Distributed.RRID()
    rv = Distributed.lookup_ref(oid)
    rv.waitingfor = pid

    hdr = Distributed.MsgHeader(Distributed.RRID(0,0), oid)
    header = AMHeader(Distributed.myid(), hdr)
    msg = Distributed.CallMsg{:call_fetch}(f, args, kwargs)

    req = send_msg(pid, header, msg, AM_REMOTECALL_FETCH)
    wait(req)
    v = take!(rv)
    lock(Distributed.client_refs) do
        delete!(Distributed.PGRP.refs, oid)
    end
    return isa(v, Distributed.RemoteException) ? throw(v) : v
end

function remotecall_wait(f, pid, args...; kwargs...)
    prid = Distributed.RRID()
    rv = Distributed.lookup_ref(prid)
    rv.waitingfor = pid
    rr = Distributed.Future(pid)
    ur = UCXFuture(rr)

    hdr = Distributed.MsgHeader(Distributed.remoteref_id(rr), prid)
    header = AMHeader(Distributed.myid(), hdr)
    msg = Distributed.CallWaitMsg(f, args, kwargs)

    req = send_msg(pid, header, msg, AM_REMOTECALL_WAIT)
    wait(req)
    v = fetch(rv.c)
    lock(Distributed.client_refs) do
        delete!(Distributed.PGRP.refs, prid)
    end
    isa(v, Distributed.RemoteException) && throw(v)
    return ur
end

function remote_do(f, pid, args...; kwargs...)

    hdr = Distributed.MsgHeader()
    header = AMHeader(Distributed.myid(), hdr)

    msg = Distributed.RemoteDoMsg(f, args, kwargs)
    send_msg(pid, header, msg, AM_REMOTE_DO)
    # XXX: ensure that req is making progress
    nothing
end

function deliver_result(msg, oid, value)
    if msg === :call_fetch || isa(value, Distributed.RemoteException)
        val = value
    else
        val = :OK
    end

    hdr = Distributed.MsgHeader(oid)
    header = AMHeader(Distributed.myid(), hdr)
    _msg = Distributed.ResultMsg(val)

    send_msg(oid.whence, header, _msg, AM_RESULT)
end

end # module