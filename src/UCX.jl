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
        field_mask = API.UCP_PARAM_FIELD_FEATURES # |
                    #  API.UCP_PARAM_FIELD_REQUEST_SIZE |
                    #  API.UCP_PARAM_FIELD_REQUEST_INIT

        # We always request UCP_FEATURE_WAKEUP even when in blocking mode
        # See <https://github.com/rapidsai/ucx-py/pull/377>
        # There is also AM (atomic) and RMA features
        features   = API.UCP_FEATURE_TAG |
                     API.UCP_FEATURE_WAKEUP |
                     API.UCP_FEATURE_STREAM
        
        # TODO requests
        request_size = 0
        request_init = C_NULL
        params = Ref{API.ucp_params}()
        memzero!(params)
        set!(params, :field_mask, field_mask)
        set!(params, :features, features)

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
        field_mask = API.UCP_WORKER_PARAM_FIELD_THREAD_MODE
        thread_mode = API.UCS_THREAD_MODE_MULTI

        params = Ref{API.ucp_worker_params}()
        memzero!(params)
        set!(params, :field_mask, field_mask)
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

mutable struct UCXEndpoint
    handle::API.ucp_ep_h
    worker::UCXWorker

    function UCXEndpoint(worker::UCXWorker, handle::API.ucp_ep_h)
        endpoint = new(worker, handle)
        finalizer(endpoint) do endpoint
            API.ucp_ep_destroy(endpoint.handle)
        end
        endpoint
    end
end

mutable struct UCXListener
    handle::API.ucp_listener_h
    worker::UCXWorker
    port::Cint

    function UCXListener(worker::UCXWorker, port)
        ip = IPv4(API.IP.INADDR_ANY)
        sockaddr = Ref(API.IP.sockaddr_in(InetAddr(ip, port)))
        r_handle = Ref{API.ucp_listener_h}()

        GC.@preserve sockaddr begin
            ptr = Base.unsafe_convert(Ptr{API.sockaddr}, sockaddr)
            ucs_sockaddr = API.ucs_sock_addr(ptr, sizeof(sockaddr))
            field_mask = API.UCP_LISTENER_PARAM_FIELD_SOCK_ADDR

            params = Ref{API.ucp_listener_params}()
            memzero!(params)
            set!(params, :field_mask, field_mask)
            set!(params, :sockaddr, ucs_sockaddr)

            status = API.ucp_listener_create(worker.handle, params, r_handle)
            @assert status === API.UCS_OK
        end  

        new(r_handle[], worker, port)
    end
end




end
