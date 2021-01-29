module UCX

using Sockets: InetAddr, IPv4

include("api.jl")

function memzero!(ref::Ref)
    ccall(:memset, Ptr{Cvoid}, (Ptr{Cvoid}, Cint, Csize_t), ref, 0, sizeof(ref))
end

Base.@pure function find_field(::Type{T}, fieldname) where T
    findfirst(f->f === fieldname, fieldnames(T))
end

@inline function set!(ref::Ref{T}, fieldname, val) where T
    field = find_field(T, fieldname)
    offset = fieldoffset(T, field)
    GC.@preserve ref begin
        base_ptr =  Base.unsafe_convert(Ptr{T}, ref)
        ptr = reinterpret(UInt, base_ptr) + offset
        Base.unsafe_store!(reinterpret(Ptr{fieldtype(T, field)}, ptr), val)
    end
    val
end

uintptr_t(ptr::Ptr) = reinterpret(UInt, ptr)
uintptr_t(status::API.ucs_status_t) = reinterpret(UInt, convert(Int, status))

UCS_PTR_STATUS(ptr::Ptr{Cvoid}) = API.ucs_status_t(reinterpret(UInt, ptr)) 
UCS_PTR_IS_ERR(ptr::Ptr{Cvoid}) = uintptr_t(ptr) >= uintptr_t(API.UCS_ERR_LAST)
UCS_PTR_IS_PTR(ptr::Ptr{Cvoid}) = (uintptr_t(ptr) - 1) < (uintptr_t(API.UCS_ERR_LAST) - 1)

struct UCXError
    ctx::String
    status::API.ucs_status_t
end

function version()
    major = Ref{Cuint}()
    minor = Ref{Cuint}()
    patch = Ref{Cuint}()
    API.ucp_get_version(major, minor, patch)
    VersionNumber(major[], minor[], patch[])
end

function __init__()
    lib_ver = version()
    api_ver = VersionNumber(API.UCP_API_MAJOR, 
                            API.UCP_API_MINOR,
                            lib_ver.patch)
    # TODO: Support multiple library versions in one package.
    @assert lib_ver === api_ver
end

mutable struct UCXContext
    handle::API.ucp_context_h

    function UCXContext()
        field_mask   = API.UCP_PARAM_FIELD_FEATURES

        # We always request UCP_FEATURE_WAKEUP even when in blocking mode
        # See <https://github.com/rapidsai/ucx-py/pull/377>
        # There is also AMO32 & AMO64 (atomic), RMA, and AM
        features     = API.UCP_FEATURE_TAG |
                       API.UCP_FEATURE_WAKEUP |
                       API.UCP_FEATURE_STREAM

        params = Ref{API.ucp_params}()
        memzero!(params)
        set!(params, :field_mask,   field_mask)
        set!(params, :features,     features)

        config = C_NULL
        # TODO config

        r_handle = Ref{API.ucp_context_h}()
        # UCP.ucp_init is a header function so we call, UCP.ucp_init_version
        status = API.ucp_init_version(API.UCP_API_MAJOR, API.UCP_API_MINOR,
                                      params, config, r_handle)
        @assert status === API.UCS_OK

        context = new(r_handle[])

        finalizer(context) do context
            API.ucp_cleanup(context.handle)
        end
    end
end

mutable struct UCXWorker
    handle::API.ucp_worker_h
    context::UCXContext

    function UCXWorker(context::UCXContext)
        field_mask  = API.UCP_WORKER_PARAM_FIELD_THREAD_MODE
        thread_mode = API.UCS_THREAD_MODE_MULTI

        params = Ref{API.ucp_worker_params}()
        memzero!(params)
        set!(params, :field_mask,  field_mask)
        set!(params, :thread_mode, thread_mode)

        r_handle = Ref{API.ucp_worker_h}()
        status = API.ucp_worker_create(context.handle, params, r_handle)
        @assert status === API.UCS_OK

        worker = new(r_handle[], context)
        finalizer(worker) do worker
            API.ucp_worker_destroy(worker.handle)
        end
        return worker
    end
end

function progress(worker::UCXWorker)
    API.ucp_worker_progress(worker.handle) !== 0
end

function arm(worker::UCXWorker)
    status = API.ucp_worker_arm(worker.handle)
    if status == API.UCS_ERR_BUSY
        return false
    end
    @assert status == API.UCS_OK
    return true
end

struct UCXConnectionRequest
    handle::API.ucp_conn_request_h
end

mutable struct UCXEndpoint
    handle::API.ucp_ep_h
    worker::UCXWorker
    open::Bool

    function UCXEndpoint(worker::UCXWorker, handle::API.ucp_ep_h)
        endpoint = new(handle, worker, true)
        finalizer(endpoint) do endpoint
            API.ucp_ep_destroy(endpoint.handle)
        end
        endpoint
    end
end

function Base.isopen(ep::UCXEndpoint)
    ep.open
end

function UCXEndpoint(worker::UCXWorker, ip::IPv4, port)
    field_mask = API.UCP_EP_PARAM_FIELD_FLAGS |
                 API.UCP_EP_PARAM_FIELD_SOCK_ADDR
    flags      = API.UCP_EP_PARAMS_FLAGS_CLIENT_SERVER
    sockaddr   = Ref(API.IP.sockaddr_in(InetAddr(ip, port)))

    r_handle = Ref{API.ucp_ep_h}()
    GC.@preserve sockaddr begin
        ptr = Base.unsafe_convert(Ptr{API.sockaddr}, sockaddr)
        ucs_sockaddr = API.ucs_sock_addr(ptr, sizeof(sockaddr))

        params = Ref{API.ucp_ep_params}()
        memzero!(params)
        set!(params, :field_mask,   field_mask)
        set!(params, :sockaddr,     ucs_sockaddr)
        set!(params, :flags,        flags)

        # TODO: Error callback
    
        status = API.ucp_ep_create(worker.handle, params, r_handle)
        @assert status == API.UCS_OK
    end

    UCXEndpoint(worker, r_handle[])
end

function UCXEndpoint(worker::UCXWorker, conn_request::UCXConnectionRequest)
    field_mask = API.UCP_EP_PARAM_FIELD_FLAGS |
                 API.UCP_EP_PARAM_FIELD_CONN_REQUEST
    flags      = API.UCP_EP_PARAMS_FLAGS_NO_LOOPBACK

    params = Ref{API.ucp_ep_params}()
    memzero!(params)
    set!(params, :field_mask,   field_mask)
    set!(params, :conn_request, conn_request.handle)
    set!(params, :flags,        flags)

    # TODO: Error callback

    r_handle = Ref{API.ucp_ep_h}()
    status = API.ucp_ep_create(worker.handle, params, r_handle)
    @assert status == API.UCS_OK

    UCXEndpoint(worker, r_handle[])
end

function listener_callback(conn_request_h::API.ucp_conn_request_h, args::Ptr{Cvoid})
    nothing
end

mutable struct UCXListener
    handle::API.ucp_listener_h
    worker::UCXWorker
    port::Cint

    function UCXListener(worker::UCXWorker, port, 
                         callback::Union{Ptr{Cvoid}, Base.CFunction} = @cfunction(listener_callback, Cvoid, (API.ucp_conn_request_h, Ptr{Cvoid})),
                         args::Ptr{Cvoid} = C_NULL)
        field_mask   = API.UCP_LISTENER_PARAM_FIELD_SOCK_ADDR |
                       API.UCP_LISTENER_PARAM_FIELD_CONN_HANDLER
        sockaddr     = Ref(API.IP.sockaddr_in(InetAddr(IPv4(API.IP.INADDR_ANY), port)))
        conn_handler = API.ucp_listener_conn_handler(Base.unsafe_convert(Ptr{Cvoid}, callback), args)

        r_handle = Ref{API.ucp_listener_h}()
        GC.@preserve sockaddr begin
            ptr = Base.unsafe_convert(Ptr{API.sockaddr}, sockaddr)
            ucs_sockaddr = API.ucs_sock_addr(ptr, sizeof(sockaddr))

            params = Ref{API.ucp_listener_params}()
            memzero!(params)
            set!(params, :field_mask, field_mask)
            set!(params, :sockaddr, ucs_sockaddr)
            set!(params, :conn_handler, conn_handler)

            status = API.ucp_listener_create(worker.handle, params, r_handle)
            @assert status === API.UCS_OK
        end  

        new(r_handle[], worker, port)
    end
end

function reject(listener::UCXListener, conn_request::UCXConnectionRequest)
    status = API.ucp_listener_reject(listener.handle, conn_request.handle)
    @assert status === API.UCS_OK
end

function ucp_dt_make_contig(elem_size)
    ((elem_size%API.ucp_datatype_t) << convert(API.ucp_datatype_t, API.UCP_DATATYPE_SHIFT)) | API.UCP_DATATYPE_CONTIG
end

##
# UCX tagged send and receive
##

function send_callback(request::Ptr{Cvoid}, status::API.ucs_status_t)
    nothing
end

function recv_callback(request::Ptr{Cvoid}, status::API.ucs_status_t, info::Ptr{API.ucp_tag_recv_info_t})
    nothing
end

# Current implementation is blocking
handle_request(ep::UCXEndpoint, ptr) = handle_request(ep.worker, ptr)
function handle_request(worker::UCXWorker, ptr)
    if ptr === C_NULL
        return API.UCS_OK
    elseif UCS_PTR_IS_ERR(ptr)
        return UCS_PTR_STATUS(ptr)
    else
        status = API.ucp_request_check_status(ptr)
        while(status === API.UCS_INPROGRESS)
            progress(worker)
            yield()
            status = API.ucp_request_check_status(ptr)
        end
        API.ucp_request_free(ptr)
        return status
    end
end


function send(ep::UCXEndpoint, buffer, nbytes, tag)
    dt = ucp_dt_make_contig(1) # since we are sending nbytes
    cb = @cfunction(send_callback, Cvoid, (Ptr{Cvoid}, API.ucs_status_t))

    GC.@preserve buffer begin
        data = pointer(buffer)

        ptr = API.ucp_tag_send_nb(ep.handle, data, nbytes, dt, tag, cb)
        return handle_request(ep, ptr)
    end
end

function recv(worker::UCXWorker, buffer, nbytes, tag, tag_mask=~zero(UCX.API.ucp_tag_t))
    dt = ucp_dt_make_contig(1)
    cb = @cfunction(recv_callback, Cvoid, (Ptr{Cvoid}, API.ucs_status_t, Ptr{API.ucp_tag_recv_info_t}))

    GC.@preserve buffer begin
        data = pointer(buffer)
        ptr = API.ucp_tag_recv_nb(worker.handle, data, nbytes, dt, tag, tag_mask, cb)
        return handle_request(worker, ptr)
    end
end

struct UCXMessage
    handle::API.ucp_tag_message_h
    info::API.ucp_tag_recv_info_t
end

function probe(worker::UCXWorker, tag, tag_mask=~zero(UCX.API.ucp_tag_t), remove=true)
    info = Ref{API.ucp_tag_recv_info_t}()
    message_h = API.ucp_tag_probe_nb(worker.handle, tag, tag_mask, remove, info)
    if message_h === C_NULL
        return nothing
    else
        return UCXMessage(message_h, info[])
    end
end

function recv(worker::UCXWorker, msg::UCXMessage, buffer, nbytes)
    dt = ucp_dt_make_contig(sizeof(eltype(buffer)))
    cb = @cfunction(recv_callback, Cvoid, (Ptr{Cvoid}, API.ucs_status_t, Ptr{API.ucp_tag_recv_info_t}))

    GC.@preserve data begin
        data = pointer(buffer)

        ptr = API.ucp_tag_msg_recv_nb(worker.handle, data, nbytes, dt, msg.handle, cb)
        return handle_request(worker, ptr)
    end
end

# UCX stream interface

function stream_send(ep::UCXEndpoint, buffer, nbytes)
    dt = ucp_dt_make_contig(1) # since we are sending nbytes
    cb = @cfunction(send_callback, Cvoid, (Ptr{Cvoid}, API.ucs_status_t))

    GC.@preserve buffer begin
        data = pointer(buffer)

        ptr = API.ucp_stream_send_nb(ep.handle, data, nbytes, dt, cb, #=flags=# 0)
        return handle_request(ep, ptr)
    end
end

function stream_recv(ep::UCXEndpoint, buffer, nbytes)
    dt = ucp_dt_make_contig(1) # since we are sending nbytes
    cb = @cfunction(send_callback, Cvoid, (Ptr{Cvoid}, API.ucs_status_t))

    GC.@preserve buffer begin
        data = pointer(buffer)

        length = Ref{Csize_t}(0)
        ptr = API.ucp_stream_recv_nb(ep.handle, data, nbytes, dt, cb, length, API.UCP_STREAM_RECV_FLAG_WAITALL)
        return handle_request(ep, ptr)
    end
end

# RMA

# Atomics

# AM

# Collectives

end #module
