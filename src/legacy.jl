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

struct AMArg
    rr::Distributed.RRID
end

function ensure_args(args)
    map(args) do arg
        if arg isa AMArg
            Distributed.take_ref(arg.rr, Distributed.myid())
        else
            return arg
        end
    end
end

function handle_msg(msg::Distributed.CallMsg{:call}, header)
    Distributed.schedule_call(header.response_oid, ()->msg.f(msg.args...; msg.kwargs...))
end

function handle_msg(msg::Distributed.CallMsg{:call_fetch}, header)
    UCX.@async_showerr begin
        args = ensure_args(msg.args)
        v = Distributed.run_work_thunk(()->msg.f(args...; msg.kwargs...), false)
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
        args = ensure_args(msg.args)
        rv = Distributed.schedule_call(header.response_oid, ()->msg.f(args...; msg.kwargs...))
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
    value, = ensure_args((msg.value,))
    put!(Distributed.lookup_ref(header.response_oid), value)
end

@inline function deserialize_msg(::Type{Msg}, from, data) where Msg
    buf = IOBuffer(data)
    msg = lock(proc_to_serializer_recv(from)) do serializer
        prev_io = serializer.io
        serializer.io = buf
        msg = Base.invokelatest(Distributed.deserialize_msg, serializer)::Msg
        serializer.io = prev_io 
        msg
    end
end

@inline function am_handler(::Type{Msg}, worker, header, header_length, data, length, _param) where Msg
    @assert header_length == sizeof(AMHeader)
    phdr = Base.unsafe_convert(Ptr{AMHeader}, header)
    am_hdr = Base.unsafe_load(phdr)
    from = am_hdr.from

    param = Base.unsafe_load(_param)::UCX.API.ucp_am_recv_param_t
    if (param.recv_attr & UCX.API.UCP_AM_RECV_ATTR_FLAG_RNDV) == 0
        # For small messages do a synchronous receive
        if length < 512
            ptr = Base.unsafe_convert(Ptr{UInt8}, data)
            msg = deserialize_msg(Msg, from, Base.unsafe_wrap(Array, ptr, length))::Msg
            handle_msg(msg, am_hdr.hdr)
            return UCX.API.UCS_OK
        else
            UCX.@spawn_showerr begin
                ptr = Base.unsafe_convert(Ptr{UInt8}, data)
                msg = deserialize_msg(Msg, from, Base.unsafe_wrap(Array, ptr, length))::Msg
                UCX.am_data_release(worker, data)
                handle_msg(msg, am_hdr.hdr)
            end
            return UCX.API.UCS_INPROGRESS
        end
    else
        @assert (param.recv_attr & UCX.API.UCP_AM_RECV_ATTR_FLAG_RNDV) != 0
        UCX.@spawn_showerr begin
            # Allocate rendezvous buffer
            buffer = Array{UInt8}(undef, length)
            req = UCX.am_recv(worker, data, buffer, length)
            wait(req)
            # UCX.am_data_release not necessary due to am_recv
            msg = deserialize_msg(Msg, from, buffer)::Msg
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

struct AMArgHeader
    from::Int
    rr::Distributed.RRID
    alloc::Any
end

function unsafe_copyto!(out, data)
    ptr = Base.unsafe_convert(Ptr{eltype(out)}, data)
    in  = Base.unsafe_wrap(typeof(out), ptr, size(out))
    copyto!(out, in)
end

const AM_ARGUMENT = 6
function am_argument(worker, header, header_length, data, length, _param)
    # Very different from the other am endpoints. We send the type in the header
    # instead of the actual data, so that we can allocate it on the output
    buf = IOBuffer(Base.unsafe_wrap(Array, Base.unsafe_convert(Ptr{UInt8}, header), header_length))
    from = read(buf, Int)
    amarg = lock(proc_to_serializer_recv(from)) do serializer
        prev_io = serializer.io
        serializer.io = buf
        amarg = Distributed.deserialize(serializer)::AMArgHeader
        serializer.io = prev_io 
        amarg
    end

    param = Base.unsafe_load(_param)::UCX.API.ucp_am_recv_param_t
    if (param.recv_attr & UCX.API.UCP_AM_RECV_ATTR_FLAG_RNDV) == 0
        # For small messages do a synchronous receive
        if length < 512
            out = amarg.alloc()
            unsafe_copyto!(out, data)
            put!(Distributed.lookup_ref(amarg.rr), out)
            return UCX.API.UCS_OK
        else
            UCX.@spawn_showerr begin
                out = amarg.alloc()
                unsafe_copyto!(out, data)
                put!(Distributed.lookup_ref(amarg.rr), out)
                UCX.am_data_release(worker, data)
            end
            return UCX.API.UCS_INPROGRESS
        end
    else
        @assert (param.recv_attr & UCX.API.UCP_AM_RECV_ATTR_FLAG_RNDV) != 0
        UCX.@spawn_showerr begin
            # Allocate rendezvous buffer
            out = amarg.alloc()
            req = UCX.am_recv(worker, data, out, length)
            wait(req)
            # UCX.am_data_release not necessary due to am_recv
            put!(Distributed.lookup_ref(amarg.rr), out)
        end
        return UCX.API.UCS_INPROGRESS
    end
end

function start()
    ctx = UCX.UCXContext()
    worker = UCX.UCXWorker(ctx)

    UCX.AMHandler(worker, am_remotecall,       AM_REMOTECALL) 
    UCX.AMHandler(worker, am_remotecall_fetch, AM_REMOTECALL_FETCH) 
    UCX.AMHandler(worker, am_remotecall_wait,  AM_REMOTECALL_WAIT)
    UCX.AMHandler(worker, am_remote_do,        AM_REMOTE_DO)
    UCX.AMHandler(worker, am_result,           AM_RESULT)
    UCX.AMHandler(worker, am_argument,         AM_ARGUMENT)

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
    lock::Base.Threads.SpinLock
end
function Base.lock(f, ucx::UCXSerializer)
    lock(ucx.lock) do
        f(ucx.serializer)
    end
end

const UCX_PROC_ENDPOINT = Dict{Int, UCX.UCXEndpoint}()
const UCX_ADDR_LISTING  = Dict{Int, Vector{UInt8}}()
const UCX_SERIALIZERS_SEND = Dict{Int, UCXSerializer}()
const UCX_SERIALIZERS_RECV = Dict{Int, UCXSerializer}()

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

function proc_to_serializer_send(p)
    this = get!(UCX_SERIALIZERS_SEND, p) do
        cs = Distributed.ClusterSerializer(IOBuffer())
        cs.pid = p
        UCXSerializer(cs, Base.Threads.SpinLock())
    end
end

function proc_to_serializer_recv(p)
    this = get!(UCX_SERIALIZERS_RECV, p) do
        cs = Distributed.ClusterSerializer(IOBuffer())
        cs.pid = p
        UCXSerializer(cs, Base.Threads.SpinLock())
    end
end

@inline function send_msg(pid, hdr, msg, id, notify=false)
    # Short circuit self send
    if pid == hdr.from
        req = UCX.UCXRequest(UCX_WORKER, nothing)
        UCX.unroot(req)
        handle_msg(msg, hdr.hdr)
        Base.notify(req)
        req
    else
        ep = proc_to_endpoint(pid)
        data = lock(proc_to_serializer_send(pid)) do serializer
            Base.invokelatest(Distributed.serialize_msg, serializer, msg)
            take!(serializer.io)
        end

        header = Ref(hdr)

        UCX.fence(ep.worker) # Gurantuee order
        req = UCX.am_send(ep, id, header, data)
        notify && Base.notify(ep.worker)
        req
    end
end

# TODO:
# views
@inline function send_arg(pid, arg::Array{T, N}) where {T, N}
    self = Distributed.myid()
    if self != pid && Base.isbitstype(T)
        rr = Distributed.RRID()
        shape = size(arg)
        alloc = ()->Array{T,N}(undef, shape)
        header = AMArgHeader(self, rr, alloc)

        ep = proc_to_endpoint(pid)
        raw_header = lock(proc_to_serializer_send(pid)) do serializer
            write(serializer.io, Int(header.from)) # yes...
            Base.invokelatest(Distributed.serialize, serializer, header)
            take!(serializer.io)
        end

        UCX.fence(ep.worker) # Gurantuee order
        UCX.am_send(ep, AM_ARGUMENT, raw_header, arg)
        notify(ep.worker) # wake worker up to make progress quicker
        return AMArg(rr)
    else
        return arg
    end
end
send_arg(pid, arg::Any) = arg

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

    req = send_msg(pid, header, msg, AM_REMOTECALL, #=notify=# true)
    UCXFuture(rr)
end

function remotecall_fetch(f, pid, args...; kwargs...)
    oid = Distributed.RRID()
    rv = Distributed.lookup_ref(oid)
    rv.waitingfor = pid

    hdr = Distributed.MsgHeader(Distributed.RRID(0,0), oid)
    header = AMHeader(Distributed.myid(), hdr)
    args = map((arg)->send_arg(pid, arg), args)
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
    args = map((arg)->send_arg(pid, arg), args)
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
    send_msg(pid, header, msg, AM_REMOTE_DO, #=notify=# true)
    nothing
end

function deliver_result(msg, oid, value)
    if msg === :call_fetch || isa(value, Distributed.RemoteException)
        val = value
    else
        val = :OK
    end

    val = send_arg(oid.whence, val)

    hdr = Distributed.MsgHeader(oid)
    header = AMHeader(Distributed.myid(), hdr)
    _msg = Distributed.ResultMsg(val)

    send_msg(oid.whence, header, _msg, AM_RESULT)
end

end # module