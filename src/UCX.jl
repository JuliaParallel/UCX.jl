module UCX

using Sockets: InetAddr, IPv4, listenany
using Random
import FunctionWrappers: FunctionWrapper

const PROGRESS_MODE = Ref(:idling)

include("api.jl")
include("ip.jl")

function __init__()
    # Julia multithreading uses SIGSEGV to sync thread
    # https://docs.julialang.org/en/v1/devdocs/debuggingtips/#Dealing-with-signals-1
    # By default, UCX will error if this occurs (see https://github.com/JuliaParallel/MPI.jl/issues/337)
    # This is a global flag and can't be set per context, since Julia generally
    # handles signals I don't see any additional value in having UCX mess with
    # signal handlers. Setting the environment here does not work, since it is
    # global, not context specific, and is being parsed on library load.

    # reinstall signal handlers
    ccall((:ucs_debug_disable_signals, API.libucs), Cvoid, ())

    @assert version() >= VersionNumber(API.UCP_API_MAJOR, API.UCP_API_MINOR)
    mode = get(ENV, "JLUCX_PROGRESS_MODE", "idling")
    if mode == "busy"
        PROGRESS_MODE[] = :busy
    elseif mode == "idling"
        PROGRESS_MODE[] = :idling
    elseif mode == "polling"
        PROGRESS_MODE[] = :polling
    elseif mode == "libuv"
        PROGRESS_MODE[] = :libuv
    else
        error("JLUCX_PROGRESS_MODE set to unkown progress mode: $mode")
    end
    @debug "UCX progress mode" mode
end

function memzero!(ref::Ref)
    ccall(:memset, Ptr{Cvoid}, (Ptr{Cvoid}, Cint, Csize_t), ref, 0, sizeof(ref))
end

Base.@pure function find_field(::Type{T}, fieldname) where T
    findfirst(f->f === fieldname, fieldnames(T))
end

@inline function unsafe_fieldptr(ref::Ref{T}, fieldname) where T
    field = find_field(T, fieldname)
    @assert field !== nothing
    offset = fieldoffset(T, field)
    base_ptr =  Base.unsafe_convert(Ptr{T}, ref)
    ptr = reinterpret(UInt, base_ptr) + offset
    return reinterpret(Ptr{fieldtype(T, field)}, ptr)
end

@inline function set!(ref::Ref{T}, fieldname, val) where T
    GC.@preserve ref begin
        Base.unsafe_store!(unsafe_fieldptr(ref, fieldname), val)
    end
    val
end

sync_send(data::Ptr{Cvoid}) = ccall(:uv_async_send, Cint, (Ptr{Cvoid},), data)

# Exceptions/Status

uintptr_t(ptr::Ptr) = reinterpret(UInt, ptr)
uintptr_t(status::API.ucs_status_t) = reinterpret(UInt, convert(Int, status))

UCS_PTR_STATUS(ptr::Ptr{Cvoid}) = API.ucs_status_t(reinterpret(UInt, ptr)) 
UCS_PTR_IS_ERR(ptr::Ptr{Cvoid}) = uintptr_t(ptr) >= uintptr_t(API.UCS_ERR_LAST)
UCS_PTR_IS_PTR(ptr::Ptr{Cvoid}) = (uintptr_t(ptr) - 1) < (uintptr_t(API.UCS_ERR_LAST) - 1)

struct UCXException <: Exception
    status::API.ucs_status_t
end

macro check(ex)
    quote
        status = $(esc(ex))
        if status != API.UCS_OK
            throw(UCXException(status))
        end
    end
end

# Utils

macro async_showerr(ex)
    esc(quote
        @async try
            $ex
        catch err
            bt = catch_backtrace()
            showerror(stderr, err, bt)
            rethrow()
        end
    end)
end

macro spawn_showerr(ex)
    esc(quote
        Base.Threads.@spawn try
            $ex
        catch err
            bt = catch_backtrace()
            showerror(stderr, err, bt)
            rethrow()
        end
    end)
end

# Config

function version()
    major = Ref{Cuint}()
    minor = Ref{Cuint}()
    patch = Ref{Cuint}()
    API.ucp_get_version(major, minor, patch)
    VersionNumber(major[], minor[], patch[])
end

mutable struct UCXConfig
    handle::Ptr{API.ucp_config_t}

    function UCXConfig(; kwargs...)
        r_handle = Ref{Ptr{API.ucp_config_t}}()
        @check API.ucp_config_read(C_NULL, C_NULL, r_handle) # XXX: Prefix is broken

        config = new(r_handle[])
        finalizer(config) do config
            API.ucp_config_release(config)
        end

        for (key, value) in kwargs
            config[key] = string(value)
        end

        config
    end
end
Base.unsafe_convert(::Type{Ptr{API.ucp_config_t}}, config::UCXConfig) = config.handle

function Base.setindex!(config::UCXConfig, value::String, key::Union{String, Symbol})
    @check API.ucp_config_modify(config, key, value)
    return value
end

function Base.parse(::Type{Dict}, config::UCXConfig)
    ptr  = Ref{Ptr{Cchar}}()
    size = Ref{Csize_t}()
    fd   = ccall(:open_memstream, Ptr{API.FILE}, (Ptr{Ptr{Cchar}}, Ptr{Csize_t}), ptr, size)

    # Flush the just created fd to have `ptr` be valid
    systemerror("fflush", ccall(:fflush, Cint, (Ptr{API.FILE},), fd) != 0)

    try
        API.ucp_config_print(config, fd, C_NULL, API.UCS_CONFIG_PRINT_CONFIG)
        systemerror("fclose", ccall(:fclose, Cint, (Ptr{API.FILE},), fd) != 0)
    catch
        Base.Libc.free(ptr[])
        rethrow()
    end
    io = IOBuffer(unsafe_wrap(Array, Base.unsafe_convert(Ptr{UInt8}, ptr[]), (size[],), own=true))

    dict = Dict{Symbol, String}()
    for line in readlines(io)
        key, value = split(line, '=')
        key = key[5:end] # Remove `UCX_`
        dict[Symbol(key)] = value
    end
    return dict
end

mutable struct UCXContext
    handle::API.ucp_context_h
    config::Dict{Symbol, String}

    function UCXContext(wakeup = true; kwargs...)
        field_mask   = API.UCP_PARAM_FIELD_FEATURES

        # Note: ucx-py always request UCP_FEATURE_WAKEUP even when in blocking mode
        # See <https://github.com/rapidsai/ucx-py/pull/377>

        # There is also AMO32 & AMO64 (atomic), RMA,
        features     = API.UCP_FEATURE_TAG |
                       API.UCP_FEATURE_STREAM |
                       API.UCP_FEATURE_AM |
                       API.UCP_FEATURE_RMA

        if wakeup
            features |= API.UCP_FEATURE_WAKEUP
        end

        params = Ref{API.ucp_params}()
        memzero!(params)
        set!(params, :field_mask,      field_mask)
        set!(params, :features,        features)

        config = UCXConfig(; kwargs...)

        r_handle = Ref{API.ucp_context_h}()
        # UCP.ucp_init is a header function so we call, UCP.ucp_init_version
        @check API.ucp_init_version(API.UCP_API_MAJOR, API.UCP_API_MINOR,
                                    params, config, r_handle)

        context = new(r_handle[], parse(Dict, config))

        finalizer(context) do context
            API.ucp_cleanup(context)
        end
    end
end
Base.unsafe_convert(::Type{API.ucp_context_h}, ctx::UCXContext) = ctx.handle

function info(ucx::UCXContext)
    ptr  = Ref{Ptr{Cchar}}()
    size = Ref{Csize_t}()
    fd   = ccall(:open_memstream, Ptr{API.FILE}, (Ptr{Ptr{Cchar}}, Ptr{Csize_t}), ptr, size)

    # Flush the just created fd to have `ptr` be valid
    systemerror("fflush", ccall(:fflush, Cint, (Ptr{API.FILE},), fd) != 0)

    try
        API.ucp_context_print_info(ucx, fd)
        systemerror("fclose", ccall(:fclose, Cint, (Ptr{API.FILE},), fd) != 0)
    catch
        Base.Libc.free(ptr[])
        rethrow()
    end
    str = unsafe_string(ptr[], size[])
    Base.Libc.free(ptr[])
    str
end

function query(ctx::UCXContext)
    r_attr = Ref{API.ucp_context_attr_t}()
    API.ucp_context_query(ctx, r_attr)
    r_attr[]
end

mutable struct UCXWorker
    handle::API.ucp_worker_h
    fd::RawFD
    context::UCXContext
    inflight::IdDict{Any, Nothing} # IdSet -- Can't use UCXRequest since that is defined after
    am_handlers::Dict{UInt16, Any}
    in_amhandler::Vector{Bool}
    open::Bool
    mode::Symbol

    function UCXWorker(context::UCXContext; progress_mode=PROGRESS_MODE[])
        field_mask  = API.UCP_WORKER_PARAM_FIELD_THREAD_MODE
        thread_mode = API.UCS_THREAD_MODE_MULTI

        params = Ref{API.ucp_worker_params}()
        memzero!(params)
        set!(params, :field_mask,  field_mask)
        set!(params, :thread_mode, thread_mode)

        @debug "Creating UCXWorker" thread_mode progress_mode

        r_handle = Ref{API.ucp_worker_h}()
        @check API.ucp_worker_create(context, params, r_handle)
        handle = r_handle[]

        # TODO: Verify that UCXContext has been created with WAKEUP
        if progress_mode === :polling
            r_fd = Ref{API.Cint}()
            @check API.ucp_worker_get_efd(handle, r_fd)
            fd = Libc.RawFD(r_fd[])
        else
            fd = RawFD(-1)
        end

        worker = new(handle, fd, context, IdDict{Any,Nothing}(), Dict{UInt16, Any}(), fill(false, Base.Threads.nthreads()), true, progress_mode)
        finalizer(worker) do worker
            worker.open = false
            @assert isempty(worker.inflight)
            API.ucp_worker_destroy(worker)
        end
        return worker
    end
end
Base.unsafe_convert(::Type{API.ucp_worker_h}, worker::UCXWorker) = worker.handle

ispolling(worker::UCXWorker) = worker.fd != RawFD(-1)
progress_mode(worker::UCXWorker) = worker.mode
context(worker::UCXWorker) = worker.context

"""
    progress(worker::UCXWorker)

Allows `worker` to make progress, this includes finalizing requests
and call callbacks.

Returns `true` if progress was made, `false` if no work was waiting.
"""
function progress(worker::UCXWorker, allow_yield=true)
    tid = Base.Threads.threadid()
    if worker.in_amhandler[tid]
        @debug """
        UCXWorker is processing a Active Message on this thread
        Calling `progress` is not permitted and leads to recursion.
        """ tid exception=(UCXException(API.UCS_ERR_NO_PROGRESS), catch_backtrace())
        if allow_yield
            yield()
        end
        return false
    else
        return API.ucp_worker_progress(worker) != 0
    end
end

function async_progress(worker::UCXWorker)
    return Base.@threadcall((:ucp_worker_progress, API.libucp), Cuint, (ucp_worker_h,), worker) != 0
end

function fence(worker::UCXWorker)
    @check API.ucp_worker_fence(worker)
end

function lock_am(worker::UCXWorker)
    tid = Base.Threads.threadid()
    if worker.in_amhandler[tid]
        error("UCXWorker already in AMHandler on this thread! Concurrency violation.")
    end
    worker.in_amhandler[tid] = true
end

function unlock_am(worker::UCXWorker)
    tid = Base.Threads.threadid()
    if !worker.in_amhandler[tid]
        error("UCXWorker is not in AMHandler on this thread! Concurrency violation.")
    end
    worker.in_amhandler[tid] = false
end

include("idle.jl")

import FileWatching: poll_fd
function Base.wait(worker::UCXWorker)
    if ispolling(worker)
        @assert progress_mode(worker) === :polling
        # Use fd_poll to suspend worker when no progress is being made
        while isopen(worker)
            if progress(worker)
                # progress was made
                yield()
                continue
            end

            # Wait for poll
            status = API.ucp_worker_arm(worker)
            if status == API.UCS_OK
                if !isopen(worker)
                    error("UCXWorker already closed")
                end
                # wait for events
                poll_fd(worker.fd; writable=true, readable=true)
                progress(worker)
                break
            elseif status == API.UCS_ERR_BUSY
                # could not arm, need to progress more
                continue
            else
                @check status
            end
        end
    elseif progress_mode(worker) === :idling
        idler = UvWorkerIdle(worker)
        wait(idler)
        close(idler)
    elseif progress_mode(worker) === :busy
        progress(worker)
        while isopen(worker)
            # Temporary solution before we have gc transition support in codegen.
            # XXX: `yield()` is supposed to be a safepoint, but without this we easily
            #      deadlock in a multithreaded test.
            ccall(:jl_gc_safepoint, Cvoid, ())
            yield()
            progress(worker)
        end
    elseif progress_mode(worker) === :libuv
        async_progress(worker)
        while isopen(worker)
            async_progress(worker)
        end
    else
       throw(UCXException(API.UCS_ERR_UNREACHABLE))
    end
end

function Base.notify(worker::UCXWorker)
    # If we don't use polling, we can't signal the worker
    if ispolling(worker)
        @check API.ucp_worker_signal(worker)
    end
end

function Base.isopen(worker::UCXWorker)
    worker.open
end

function Base.close(worker::UCXWorker)
    @debug "Close worker"
    worker.open = false
    notify(worker)
end




"""
    AMHandler(func)

## Arguments to callback
  - `worker::UCXWorker`
  - `data::Ptr{Cvoid}`
  - `length::Csize_t`
  - `reply_ep::API.ucp_ep_h`
  - `flags::Cuint`

## Return values
The callback `func` needs to return either `UCX.API.UCS_OK` or `UCX.API.UCS_INPROGRESS`.
If it returns `UCX.API.UCS_INPROGRESS` it **must** call `am_data_release(worker, data)`,
or call `am_recv`.
"""
mutable struct AMHandler
    func::FunctionWrapper{API.ucs_status_t, Tuple{UCXWorker, Ptr{Cvoid}, Csize_t, Ptr{Cvoid}, Csize_t, Ptr{API.ucp_am_recv_param_t}}}
    worker::UCXWorker
end

function am_recv_callback(arg::Ptr{Cvoid}, header::Ptr{Cvoid}, header_length::Csize_t, data::Ptr{Cvoid}, length::Csize_t, param::Ptr{API.ucp_am_recv_param_t})::API.ucs_status_t
    handler = Base.unsafe_pointer_to_objref(arg)::AMHandler
    try
        lock_am(handler.worker)
        return handler.func(handler.worker, header, header_length, data, length, param)::API.ucs_status_t
    catch err
        showerror(stderr, err, catch_backtrace())
        return API.UCS_OK
    finally
        unlock_am(handler.worker)
    end
end

AMHandler(f, w::UCXWorker, id) = AMHandler(w, f, id)

function AMHandler(worker::UCXWorker, func, id)
    @debug "Installing AMHandler on worker" func id
    handler = AMHandler(func, worker)
    worker.am_handlers[id] = handler # root handler in worker

    arg = Base.pointer_from_objref(handler)
    cb  = @cfunction(am_recv_callback, API.ucs_status_t, (Ptr{Cvoid}, Ptr{Cvoid}, Csize_t, Ptr{Cvoid}, Csize_t, Ptr{API.ucp_am_recv_param_t}))

    field_mask  = API.UCP_AM_HANDLER_PARAM_FIELD_ID |
                  API.UCP_AM_HANDLER_PARAM_FIELD_CB |
                  API.UCP_AM_HANDLER_PARAM_FIELD_ARG

    params = Ref{API.ucp_am_handler_param_t}()
    memzero!(params)
    set!(params, :field_mask, field_mask)
    set!(params, :id,         id)
    set!(params, :cb,         cb)
    set!(params, :arg,        arg)

    @check API.ucp_worker_set_am_recv_handler(worker, params)
end

function delete_am!(worker::UCXWorker, id)
    delete!(worker.am_handlers, id)

    field_mask  = API.UCP_AM_HANDLER_PARAM_FIELD_ID |
                  API.UCP_AM_HANDLER_PARAM_FIELD_CB |
                  API.UCP_AM_HANDLER_PARAM_FIELD_ARG

    params = Ref{API.ucp_am_handler_param_t}()
    memzero!(params)
    set!(params, :field_mask, field_mask)
    set!(params, :id,         id)
    set!(params, :cb,         C_NULL)
    set!(params, :arg,        C_NULL)

    @check API.ucp_worker_set_am_recv_handler(worker, params)
end

function am_data_release(worker::UCXWorker, data)
    API.ucp_am_data_release(worker, data)
end

mutable struct UCXAddress
    worker::UCXWorker
    handle::Ptr{API.ucp_address_t}
    len::Csize_t

    function UCXAddress(worker::UCXWorker)
        addr = Ref{Ptr{API.ucp_address_t}}()
        len = Ref{Csize_t}()
        @check API.ucp_worker_get_address(worker, addr, len)

        this = new(worker, addr[], len[])
        finalizer(this) do addr
            API.ucp_worker_release_address(addr.worker, addr.handle)
        end
        return this
    end
end

struct UCXConnectionRequest
    handle::API.ucp_conn_request_h
end

mutable struct UCXEndpoint
    handle::API.ucp_ep_h
    worker::UCXWorker

    function UCXEndpoint(worker::UCXWorker, handle::API.ucp_ep_h)
        @assert handle != C_NULL
        endpoint = new(handle, worker)
        finalizer(endpoint) do endpoint
            # NOTE: Generally not safe to spin in finalizer
            #   - ucp_ep_destroy
            #   - ucp_ep_close_nb (Gracefully shutdown)
            #     - UCP_EP_CLOSE_MODE_FORCE
            #     - UCP_EP_CLOSE_MODE_FLUSH
            let handle = endpoint.handle # Valid since we are aleady finalizing endpoint
                @async_showerr begin
                    status = API.ucp_ep_close_nb(handle, API.UCP_EP_CLOSE_MODE_FLUSH)
                    if UCS_PTR_IS_PTR(status)
                        while API.ucp_request_check_status(status) == API.UCS_INPROGRESS
                            progress(worker)
                            yield()
                        end
                        API.ucp_request_free(status)
                    else
                        @check UCS_PTR_STATUS(status)
                    end
                end
            end
        end
        endpoint
    end
end
Base.unsafe_convert(::Type{API.ucp_ep_h}, ep::UCXEndpoint) = ep.handle

function UCXEndpoint(worker::UCXWorker, ip::IPv4, port)
    field_mask = API.UCP_EP_PARAM_FIELD_FLAGS |
                 API.UCP_EP_PARAM_FIELD_SOCK_ADDR
    flags      = API.UCP_EP_PARAMS_FLAGS_CLIENT_SERVER
    sockaddr   = Ref(IP.sockaddr_in(InetAddr(ip, port)))

    r_handle = Ref{API.ucp_ep_h}()
    GC.@preserve sockaddr begin
        ptr = Base.unsafe_convert(Ptr{IP.sockaddr_in}, sockaddr)
        addrlen = sizeof(IP.sockaddr_in)
        ucs_sockaddr = API.ucs_sock_addr(reinterpret(Ptr{API.sockaddr}, ptr), addrlen)

        params = Ref{API.ucp_ep_params}()
        memzero!(params)
        set!(params, :field_mask,   field_mask)
        set!(params, :sockaddr,     ucs_sockaddr)
        set!(params, :flags,        flags)

        # TODO: Error callback
    
        @check API.ucp_ep_create(worker, params, r_handle)
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
    @check API.ucp_ep_create(worker, params, r_handle)

    UCXEndpoint(worker, r_handle[])
end

function UCXEndpoint(worker::UCXWorker, addr::UCXAddress)
    GC.@preserve addr begin
        _UCXEndpoint(worker, addr.handle)
    end
end

function UCXEndpoint(worker::UCXWorker, addr_buf::Vector{UInt8})
    GC.@preserve addr_buf begin
        addr = Base.unsafe_convert(Ptr{API.ucp_address_t}, pointer(addr_buf))
        _UCXEndpoint(worker, addr)
    end
end

function _UCXEndpoint(worker::UCXWorker, addr::Ptr{API.ucp_address_t})
    field_mask = API.UCP_EP_PARAM_FIELD_REMOTE_ADDRESS

    r_handle = Ref{API.ucp_ep_h}()
    params = Ref{API.ucp_ep_params}()
    memzero!(params)
    set!(params, :field_mask,   field_mask)
    set!(params, :address,      addr)

    # TODO: Error callback

    @check API.ucp_ep_create(worker, params, r_handle)

    UCXEndpoint(worker, r_handle[])
end

function listener_callback(conn_request_h::API.ucp_conn_request_h, args::Ptr{Cvoid})
    conn_request = UCX.UCXConnectionRequest(conn_request_h)
    listener = Base.unsafe_pointer_to_objref(args)::UCXListener
    Base.invokelatest(listener.callback, listener, conn_request)
    nothing
end

mutable struct UCXListener
    handle::API.ucp_listener_h
    worker::UCXWorker
    port::Cint
    callback::Any

    function UCXListener(worker::UCXWorker, callback, port=nothing)
        # Choose free port
        if port === nothing || port == 0
            port_hint = 9000 + (getpid() % 1000)
            port, sock = listenany(UInt16(port_hint))
            close(sock) # FIXME: https://github.com/rapidsai/ucx-py/blob/72552d1dd1d193d1c8ce749171cdd34d64523d53/ucp/core.py#L288-L304
        end

        field_mask   = API.UCP_LISTENER_PARAM_FIELD_SOCK_ADDR |
                       API.UCP_LISTENER_PARAM_FIELD_CONN_HANDLER
        sockaddr     = Ref(IP.sockaddr_in(InetAddr(IPv4(IP.INADDR_ANY), port)))

        this = new(C_NULL, worker, port, callback)

        r_handle = Ref{API.ucp_listener_h}()
        GC.@preserve sockaddr this begin
            args = Base.pointer_from_objref(this)
            conn_handler = API.ucp_listener_conn_handler(@cfunction(listener_callback, Cvoid, (API.ucp_conn_request_h, Ptr{Cvoid})), args)

            ptr = Base.unsafe_convert(Ptr{IP.sockaddr_in}, sockaddr)
            addrlen = sizeof(IP.sockaddr_in)
            ucs_sockaddr = API.ucs_sock_addr(reinterpret(Ptr{API.sockaddr}, ptr), addrlen)

            params = Ref{API.ucp_listener_params}()
            memzero!(params)
            set!(params, :field_mask, field_mask)
            set!(params, :sockaddr, ucs_sockaddr)
            set!(params, :conn_handler, conn_handler)

            @check API.ucp_listener_create(worker, params, r_handle)
        end

        this.handle = r_handle[]

        finalizer(this) do listener
            API.ucp_listener_destroy(listener)
        end

        this
    end
end
Base.unsafe_convert(::Type{API.ucp_listener_h}, listener::UCXListener) = listener.handle

function reject(listener::UCXListener, conn_request::UCXConnectionRequest)
    @check API.ucp_listener_reject(listener, conn_request.handle)
end

function ucp_dt_make_contig(elem_size)
    ((elem_size%API.ucp_datatype_t) << convert(API.ucp_datatype_t, API.UCP_DATATYPE_SHIFT)) | API.UCP_DATATYPE_CONTIG
end

##
# UCX Memory
##

# TODO: Support memory_type
mutable struct Memory
    handle::API.ucp_mem_h
    ctx::UCXContext
    base::UInt64
    obj

    function Memory(ctx::UCXContext, obj, addr::Ptr, length)
        field_mask = API.UCP_MEM_MAP_PARAM_FIELD_ADDRESS |
                     API.UCP_MEM_MAP_PARAM_FIELD_LENGTH

        # if data === nothing
        #     @assert addr == C_NULL
        #     field_mask |= API.UCP_MEM_MAP_PARAM_FIELD_FLAGS
        # end
        
        params = Ref{API.ucp_mem_map_params}()
        memzero!(params)
        set!(params, :field_mask,   field_mask)
        set!(params, :address,      addr)
        set!(params, :length,       length)
        # if data === nothing
        #     set!(params, :flags, API.UCP_MEM_MAP_NONBLOCK | API.UCP_MEM_MAP_ALLOCATE)
        # end

        r_handle = Ref{API.ucp_mem_h}()
        @check API.ucp_mem_map(ctx, params, r_handle)

        base = UInt64(reinterpret(UInt, addr))
        this = new(r_handle[], ctx, base, obj)
        finalizer(this) do memory
            API.ucp_mem_unmap(memory.ctx, memory)
        end
        this
    end
end
Base.unsafe_convert(::Type{API.ucp_mem_h}, memory::Memory) = memory.handle

function Memory(ctx::UCXContext, arr::Array)
    Memory(ctx, arr, pointer(arr), sizeof(arr))
end

##
# RemoteKey
## 

mutable struct RemoteKey
    handle::API.ucp_rkey_h

    function RemoteKey(ep::UCXEndpoint, buffer)
        r_rkey = Ref{API.ucp_rkey_h}()
        @check API.ucp_ep_rkey_unpack(ep, buffer, r_rkey)
        this = new(r_rkey[])
        finalizer(this) do rkey
            API.ucp_rkey_destroy(rkey)
        end
        this
    end
end
Base.unsafe_convert(::Type{API.ucp_rkey_h}, rkey::RemoteKey) = rkey.handle

function rkey_pack(memory::Memory)
    r_data = Ref{Ptr{Cvoid}}()
    r_size = Ref{Csize_t}()
    @check API.ucp_rkey_pack(memory.ctx, memory, r_data, r_size)
    buffer = copy(unsafe_wrap(Array{UInt8}, Base.unsafe_convert(Ptr{UInt8}, r_data[]), r_size[] % Int, own=false))
    API.ucp_rkey_buffer_release(r_data[])
    return buffer
end

function Base.pointer(rkey::RemoteKey, raddr::UInt64)
    r_ptr = Ref{Ptr{Cvoid}}()
    @check API.ucp_rkey_ptr(rkey, raddr, r_ptr)
    return r_ptr[]
end

##
# Request handling
##

# User representation of a request
# don't create these manually
mutable struct UCXRequest
    worker::UCXWorker
    event::Base.Event
    status::API.ucs_status_t
    data::Any
    function UCXRequest(worker::UCXWorker, data)
        req = new(worker, Base.Event(), API.UCS_OK, data)
        worker.inflight[req] = nothing
        return req
    end
end
UCXRequest(ep::UCXEndpoint, data) = UCXRequest(ep.worker, data)

function unroot(request::UCXRequest)
    inflight = request.worker.inflight
    delete!(inflight, request)
end

function UCXRequest(_request::Ptr{Cvoid})
    request = Base.unsafe_pointer_to_objref(_request) # rooted through inflight
    unroot(request) # caller is now responsible

    return request
end

@inline function handle_request(request::UCXRequest, ptr)
    if !UCS_PTR_IS_PTR(ptr)
        # Request is already done
        unroot(request)
        status = UCS_PTR_STATUS(ptr)
        request.status = status
        notify(request)
    end
    return request
end

Base.notify(req::UCXRequest) = notify(req.event)
function Base.wait(req::UCXRequest)
    if progress_mode(req.worker) === :busy
        # The worker will make independent progress
        # and if we don't suspend here we will get a livelock.
        wait(req.event)
        @check req.status
    else
        # Request busy loop
        # It can be that only due to us calling progress we will trigger
        # the Event, and the Worker will suspend due to the use of polling.
        progress(req.worker)
        ev = req.event
        while true
            lock(ev.notify)
            if ev.set
                break
            end
            unlock(ev.notify)
            yield()
            progress(req.worker)
        end
        unlock(ev.notify)
        @check req.status
    end
end

##
# UCX tagged send and receive
##

function send_callback(req::Ptr{Cvoid}, status::API.ucs_status_t, user_data::Ptr{Cvoid})
    @assert user_data !== C_NULL
    request = UCXRequest(user_data)
    request.status = status
    notify(request)
    API.ucp_request_free(req)
    nothing
end

function recv_callback(req::Ptr{Cvoid}, status::API.ucs_status_t, info::Ptr{API.ucp_tag_recv_info_t}, user_data::Ptr{Cvoid})
    @assert user_data !== C_NULL
    request = UCXRequest(user_data)
    request.status = status
    notify(request)
    API.ucp_request_free(req)
    nothing
end

@inline function request_param(dt, request, (cb, name), flags=nothing)
    attr_mask = API.UCP_OP_ATTR_FIELD_CALLBACK |
                API.UCP_OP_ATTR_FIELD_USER_DATA |
                API.UCP_OP_ATTR_FIELD_DATATYPE

    if flags !== nothing
        attr_mask |= API.UCP_OP_ATTR_FIELD_FLAGS
    end

    param = Ref{API.ucp_request_param_t}()
    memzero!(param)
    set!(param, :op_attr_mask, attr_mask)
    GC.@preserve param begin
        ptr = unsafe_fieldptr(param, :cb)
        Base.setproperty!(ptr, name, cb)
    end
    set!(param, :datatype,     dt)
    set!(param, :user_data,    Base.pointer_from_objref(request))
    if flags !== nothing
        set!(param, :flags,    flags)
    end

    param
end

function send(ep::UCXEndpoint, buffer, nbytes, tag)
    dt = ucp_dt_make_contig(1) # since we are sending nbytes
    request = UCXRequest(ep, buffer) # rooted through worker
    cb = @cfunction(send_callback, Cvoid, (Ptr{Cvoid}, API.ucs_status_t, Ptr{Cvoid}))

    param = request_param(dt, request, (cb, :send))

    GC.@preserve buffer begin
        data = pointer(buffer)
        ptr = API.ucp_tag_send_nbx(ep, data, nbytes, tag, param)
        return handle_request(request, ptr)
    end
end

function recv(worker::UCXWorker, buffer, nbytes, tag, tag_mask=~zero(UCX.API.ucp_tag_t))
    dt = ucp_dt_make_contig(1) # since we are receiving nbytes
    request = UCXRequest(worker, buffer) # rooted through worker
    cb = @cfunction(recv_callback, Cvoid, (Ptr{Cvoid}, API.ucs_status_t, Ptr{API.ucp_tag_recv_info_t}, Ptr{Cvoid}))

    param = request_param(dt, request, (cb, :recv))

    GC.@preserve buffer begin
        data = pointer(buffer)
        ptr = API.ucp_tag_recv_nbx(worker, data, nbytes, tag, tag_mask, param)
        return handle_request(request, ptr)
    end
end

# UCXWorker flush, reuses the send_callback
function Base.flush(worker::UCXWorker)
    request = UCXRequest(worker, nothing) # rooted through worker
    cb = @cfunction(send_callback, Cvoid, (Ptr{Cvoid}, API.ucs_status_t, Ptr{Cvoid}))

    dt = ucp_dt_make_contig(1) # unneeded
    param = request_param(dt, request, (cb, :send))

    ptr = API.ucp_worker_flush_nbx(worker, param)
    return handle_request(request, ptr)
end

function Base.flush(ep::UCXEndpoint)
    request = UCXRequest(ep, nothing) # rooted through worker
    cb = @cfunction(send_callback, Cvoid, (Ptr{Cvoid}, API.ucs_status_t, Ptr{Cvoid}))

    dt = ucp_dt_make_contig(1) # unneeded
    param = request_param(dt, request, (cb, :send))

    ptr = API.ucp_ep_flush_nbx(ep, param)
    return handle_request(request, ptr)
end

# UCX probe & probe msg receive

##
# UCX stream interface
##

function stream_recv_callback(req::Ptr{Cvoid}, status::API.ucs_status_t, length::Csize_t, user_data::Ptr{Cvoid})
    @assert user_data !== C_NULL
    request = UCXRequest(user_data)
    request.status = status
    notify(request)
    API.ucp_request_free(req)
    nothing
end

function stream_send(ep::UCXEndpoint, buffer, nbytes)
    request = UCXRequest(ep, buffer) # rooted through ep.worker
    GC.@preserve buffer begin
        data = pointer(buffer)
        stream_send(ep, request, data, nbytes)
    end
end

function stream_send(ep::UCXEndpoint, ref::Ref{T}) where T
    request = UCXRequest(ep, ref) # rooted through ep.worker
    GC.@preserve ref begin
        data = Base.unsafe_convert(Ptr{Cvoid}, ref)
        stream_send(ep, request, data, sizeof(T))
    end
end

function stream_send(ep::UCXEndpoint, request::UCXRequest, data::Ptr, nbytes)
    dt = ucp_dt_make_contig(1) # since we are sending nbytes
    cb = @cfunction(send_callback, Cvoid, (Ptr{Cvoid}, API.ucs_status_t, Ptr{Cvoid}))

    param = request_param(dt, request, (cb, :send))
    ptr = API.ucp_stream_send_nbx(ep, data, nbytes, param)
    return handle_request(request, ptr)
end

function stream_recv(ep::UCXEndpoint, buffer, nbytes)
    request = UCXRequest(ep, buffer) # rooted through ep.worker
    GC.@preserve buffer begin
        data = pointer(buffer)
        stream_recv(ep, request, data, nbytes)
    end
end

function stream_recv(ep::UCXEndpoint, ref::Ref{T}) where T
    request = UCXRequest(ep, ref) # rooted through ep.worker
    GC.@preserve ref begin
        data = Base.unsafe_convert(Ptr{Cvoid}, ref)
        stream_recv(ep, request, data, sizeof(T))
    end
end

function stream_recv(ep::UCXEndpoint, request::UCXRequest, data::Ptr, nbytes)
    dt = ucp_dt_make_contig(1) # since we are sending nbytes
    cb = @cfunction(stream_recv_callback, Cvoid, (Ptr{Cvoid}, API.ucs_status_t, Csize_t, Ptr{Cvoid}))
    flags = API.UCP_STREAM_RECV_FLAG_WAITALL

    length = Ref{Csize_t}(0)
    param = request_param(dt, request, (cb, :recv_stream), flags)
    ptr = API.ucp_stream_recv_nbx(ep, data, nbytes, length, param)
    return handle_request(request, ptr)
end

### TODO: stream_recv_data_nbx

## RMA


import Base.get!
function get!(ep::UCXEndpoint, request, data::Ptr, nbytes, remote_addr, rkey)
    dt = ucp_dt_make_contig(1) # since we are sending nbytes
    cb = @cfunction(send_callback, Cvoid, (Ptr{Cvoid}, API.ucs_status_t, Ptr{Cvoid}))
    param = request_param(dt, request, (cb, :send))

    ptr = API.ucp_get_nbx(ep, data, nbytes, remote_addr, rkey, param)
    return handle_request(request, ptr)
end

function get!(ep::UCXEndpoint, buffer, nbytes, remote_addr, rkey)
    request = UCXRequest(ep, buffer) # rooted through ep.worker
    GC.@preserve buffer begin
        data = pointer(buffer)
        get!(ep, request, data, nbytes, remote_addr, rkey)
    end
end

function get!(ep::UCXEndpoint, ref::Ref{T}, remote_addr, rkey) where T
    request = UCXRequest(ep, ref) # rooted through ep.worker
    GC.@preserve ref begin
        data = Base.unsafe_convert(Ptr{Cvoid}, ref)
        get!(ep, request, data, sizeof(T), remote_addr, rkey)
    end
end


import Base.put!
function put!(ep::UCXEndpoint, request, data::Ptr, nbytes, remote_addr, rkey)
    dt = ucp_dt_make_contig(1) # since we are sending nbytes
    cb = @cfunction(send_callback, Cvoid, (Ptr{Cvoid}, API.ucs_status_t, Ptr{Cvoid}))
    param = request_param(dt, request, (cb, :send))

    ptr = API.ucp_put_nbx(ep, data, nbytes, remote_addr, rkey, param)
    return handle_request(request, ptr)
end

function put!(ep::UCXEndpoint, buffer, nbytes, remote_addr, rkey)
    request = UCXRequest(ep, buffer) # rooted through ep.worker
    GC.@preserve buffer begin
        data = pointer(buffer)
        put!(ep, request, data, nbytes, remote_addr, rkey)
    end
end

function put!(ep::UCXEndpoint, ref::Ref{T}, remote_addr, rkey) where T
    request = UCXRequest(ep, ref) # rooted through ep.worker
    GC.@preserve ref begin
        data = Base.unsafe_convert(Ptr{Cvoid}, ref)
        put!(ep, request, data, sizeof(T), remote_addr, rkey)
    end
end

## Atomics

## AM

function am_send(ep::UCXEndpoint, id, header, buffer=nothing, flags=nothing)
    dt = ucp_dt_make_contig(1) # since we are sending nbytes
    cb = @cfunction(send_callback, Cvoid, (Ptr{Cvoid}, API.ucs_status_t, Ptr{Cvoid}))
    request = UCXRequest(ep, (header, buffer)) # rooted through ep.worker
    param = request_param(dt, request, (cb, :send), flags)

    GC.@preserve buffer header begin
        if buffer === nothing
            data   = C_NULL
            nbytes = 0
        else
            data = Base.unsafe_convert(Ptr{Cvoid}, Base.cconvert(Ptr{Cvoid}, buffer))
            nbytes = sizeof(buffer)
        end
        header_ptr = Base.unsafe_convert(Ptr{Cvoid}, Base.cconvert(Ptr{Cvoid}, header))

        ptr = API.ucp_am_send_nbx(ep, id, header_ptr, sizeof(header), data, nbytes, param)
    end
    return handle_request(request, ptr)
end

function am_data_recv_callback(req::Ptr{Cvoid}, status::API.ucs_status_t, length::Csize_t, user_data::Ptr{Cvoid})
    @assert user_data !== C_NULL
    request = UCXRequest(user_data)
    request.status = status
    notify(request)
    API.ucp_request_free(req)
    return nothing
end

function am_recv(worker::UCXWorker, data_desc, buffer, nbytes)
    dt = ucp_dt_make_contig(1) # since we are sending nbytes
    cb = @cfunction(am_data_recv_callback, Cvoid, (Ptr{Cvoid}, API.ucs_status_t, Csize_t, Ptr{Cvoid}))
    request = UCXRequest(worker, buffer) # rooted through ep.worker
    param = request_param(dt, request, (cb, :recv_am))

    GC.@preserve buffer begin
        data = pointer(buffer)
        ptr  = API.ucp_am_recv_data_nbx(worker, data_desc, data, nbytes, param)
    end
    return handle_request(request, ptr)
end

## Collectives

# Higher-Level API

mutable struct Worker
    worker::UCXWorker
    function Worker(ctx::UCXContext)
        new(UCXWorker(ctx))
    end
end

Base.isopen(worker::Worker) = isopen(worker.worker)
Base.notify(worker::Worker) = notify(worker.worker)
Base.wait(worker::Worker) = wait(worker.worker)
Base.close(worker::Worker) = close(worker.worker)

mutable struct Endpoint
    worker::Worker
    ep::UCXEndpoint
    msg_tag_send::API.ucp_tag_t
    msg_tag_recv::API.ucp_tag_t
end

# TODO: Tag structure
# OMPI uses msg_tag (24) | source_rank (20) | context_id (20)

tag(kind, seed, port) = hash(kind, hash(seed, hash(port)))

function Endpoint(worker::Worker, addr, port)
    ep = UCX.UCXEndpoint(worker.worker, addr, port)
    Endpoint(worker, ep, false)
end

function Endpoint(worker::Worker, connection::UCXConnectionRequest)
    ep = UCX.UCXEndpoint(worker.worker, connection)
    Endpoint(worker, ep, true)
end

function Endpoint(worker::Worker, ep::UCXEndpoint, listener)
    seed = rand(UInt128) 
    pid = getpid()
    msg_tag = tag(:ctrl, seed, pid)

    send_tag = Ref(msg_tag)
    recv_tag = Ref(msg_tag)
    if listener
        req1 = stream_send(ep, send_tag)
        req2 = stream_recv(ep, recv_tag)
    else
        req1 = stream_recv(ep, recv_tag)
        req2 = stream_send(ep, send_tag)
    end
    wait(req1)
    wait(req2)

    @assert msg_tag !== recv_tag[]

    Endpoint(worker, ep, msg_tag, recv_tag[])
end

function send(ep::Endpoint, buffer, nbytes)
    send(ep.ep, buffer, nbytes, ep.msg_tag_send)
end

function recv(ep::Endpoint, buffer, nbytes)
    recv(ep.ep.worker, buffer, nbytes, ep.msg_tag_recv)
end

function stream_send(ep::Endpoint, args...)
    stream_send(ep.ep, args...)
end

function stream_recv(ep::Endpoint, args...)
    stream_recv(ep.ep, args...)
end

struct RemoteArray{T,N} <: AbstractArray{T,N}
    ep::UCXEndpoint
    remote_addr::UInt64
    rkey::RemoteKey
    dims::NTuple{N, Int}

    function RemoteArray{T}(ep, remote_addr, rkey, dims...) where T
        new{T, length(dims)}(ep, remote_addr, rkey, dims)
    end
end

Base.size(ra::RemoteArray) = ra.dims
Base.IndexStyle(::Type{<:RemoteArray}) = Base.IndexLinear()

function Base.getindex(ra::RemoteArray{T}, index) where T
    value = Ref{T}()
    offset = ra.remote_addr + sizeof(T) * index
    wait(get!(ra.ep, value, offset % UInt64, ra.rkey)) # TODO: Optimize by avoiding allocation for `out`
    return value[]
end

function Base.setindex!(ra::RemoteArray{T}, val, index) where T
    value = Ref{T}(val)
    offset = ra.remote_addr + sizeof(T) * index
    wait(put!(ra.ep, value, offset % UInt64, ra.rkey)) # TODO: Optimize by avoiding allocation for `out`
    return value[]
end

# TODO: Implement copyto!, and optimized range get/set

end #module
