module API

using CEnum


include(joinpath(@__DIR__, "..", "deps", "deps.jl"))

const FILE = Base.Libc.FILE
const __socklen_t = Cuint
const socklen_t = __socklen_t
const sa_family_t = Cushort

# FIXME: Clang.jl should have defined this
UCS_BIT(i) = (UInt(1) << (convert(UInt, i)))
UCP_VERSION(_major, _minor) = (((_major) << UCP_VERSION_MAJOR_SHIFT) | ((_minor) << UCP_VERSION_MINOR_SHIFT))


struct sockaddr
    sa_family::sa_family_t
    sa_data::NTuple{14, Cchar}
end

@cenum ucs_status_t::Int8 begin
    UCS_OK = 0
    UCS_INPROGRESS = 1
    UCS_ERR_NO_MESSAGE = -1
    UCS_ERR_NO_RESOURCE = -2
    UCS_ERR_IO_ERROR = -3
    UCS_ERR_NO_MEMORY = -4
    UCS_ERR_INVALID_PARAM = -5
    UCS_ERR_UNREACHABLE = -6
    UCS_ERR_INVALID_ADDR = -7
    UCS_ERR_NOT_IMPLEMENTED = -8
    UCS_ERR_MESSAGE_TRUNCATED = -9
    UCS_ERR_NO_PROGRESS = -10
    UCS_ERR_BUFFER_TOO_SMALL = -11
    UCS_ERR_NO_ELEM = -12
    UCS_ERR_SOME_CONNECTS_FAILED = -13
    UCS_ERR_NO_DEVICE = -14
    UCS_ERR_BUSY = -15
    UCS_ERR_CANCELED = -16
    UCS_ERR_SHMEM_SEGMENT = -17
    UCS_ERR_ALREADY_EXISTS = -18
    UCS_ERR_OUT_OF_RANGE = -19
    UCS_ERR_TIMED_OUT = -20
    UCS_ERR_EXCEEDS_LIMIT = -21
    UCS_ERR_UNSUPPORTED = -22
    UCS_ERR_REJECTED = -23
    UCS_ERR_NOT_CONNECTED = -24
    UCS_ERR_CONNECTION_RESET = -25
    UCS_ERR_FIRST_LINK_FAILURE = -40
    UCS_ERR_LAST_LINK_FAILURE = -59
    UCS_ERR_FIRST_ENDPOINT_FAILURE = -60
    UCS_ERR_ENDPOINT_TIMEOUT = -80
    UCS_ERR_LAST_ENDPOINT_FAILURE = -89
    UCS_ERR_LAST = -100
end

const ucs_cpu_mask_t = Culong

struct ucs_cpu_set_t
    ucs_bits::NTuple{16, ucs_cpu_mask_t}
end

const ucp_datatype_t = UInt64

@cenum ucs_memory_type::UInt32 begin
    UCS_MEMORY_TYPE_HOST = 0
    UCS_MEMORY_TYPE_CUDA = 1
    UCS_MEMORY_TYPE_CUDA_MANAGED = 2
    UCS_MEMORY_TYPE_ROCM = 3
    UCS_MEMORY_TYPE_ROCM_MANAGED = 4
    UCS_MEMORY_TYPE_LAST = 5
    UCS_MEMORY_TYPE_UNKNOWN = 5
end

const ucs_memory_type_t = ucs_memory_type

const ucs_status_ptr_t = Ptr{Cvoid}

function ucs_status_string(status)
    ccall((:ucs_status_string, libucp), Ptr{Cchar}, (ucs_status_t,), status)
end

@cenum ucs_log_level_t::UInt32 begin
    UCS_LOG_LEVEL_FATAL = 0
    UCS_LOG_LEVEL_ERROR = 1
    UCS_LOG_LEVEL_WARN = 2
    UCS_LOG_LEVEL_DIAG = 3
    UCS_LOG_LEVEL_INFO = 4
    UCS_LOG_LEVEL_DEBUG = 5
    UCS_LOG_LEVEL_TRACE = 6
    UCS_LOG_LEVEL_TRACE_REQ = 7
    UCS_LOG_LEVEL_TRACE_DATA = 8
    UCS_LOG_LEVEL_TRACE_ASYNC = 9
    UCS_LOG_LEVEL_TRACE_FUNC = 10
    UCS_LOG_LEVEL_TRACE_POLL = 11
    UCS_LOG_LEVEL_LAST = 12
    UCS_LOG_LEVEL_PRINT = 13
end

@cenum ucs_async_mode_t::UInt32 begin
    UCS_ASYNC_MODE_SIGNAL = 0
    UCS_ASYNC_MODE_THREAD = 1
    UCS_ASYNC_MODE_THREAD_SPINLOCK = 1
    UCS_ASYNC_MODE_THREAD_MUTEX = 2
    UCS_ASYNC_MODE_POLL = 3
    UCS_ASYNC_MODE_LAST = 4
end

@cenum ucs_ternary_auto_value::UInt32 begin
    UCS_NO = 0
    UCS_YES = 1
    UCS_TRY = 2
    UCS_AUTO = 3
    UCS_TERNARY_LAST = 4
end

const ucs_ternary_auto_value_t = ucs_ternary_auto_value

@cenum ucs_on_off_auto_value::UInt32 begin
    UCS_CONFIG_OFF = 0
    UCS_CONFIG_ON = 1
    UCS_CONFIG_AUTO = 2
    UCS_CONFIG_ON_OFF_LAST = 3
end

const ucs_on_off_auto_value_t = ucs_on_off_auto_value

@cenum ucs_handle_error_t::UInt32 begin
    UCS_HANDLE_ERROR_BACKTRACE = 0
    UCS_HANDLE_ERROR_FREEZE = 1
    UCS_HANDLE_ERROR_DEBUG = 2
    UCS_HANDLE_ERROR_NONE = 3
    UCS_HANDLE_ERROR_LAST = 4
end

@cenum ucs_config_print_flags_t::UInt32 begin
    UCS_CONFIG_PRINT_CONFIG = 1
    UCS_CONFIG_PRINT_HEADER = 2
    UCS_CONFIG_PRINT_DOC = 4
    UCS_CONFIG_PRINT_HIDDEN = 8
    UCS_CONFIG_PRINT_COMMENT_DEFAULT = 16
end

struct ucs_config_names_array_t
    names::Ptr{Ptr{Cchar}}
    count::Cuint
    pad::Cuint
end

@cenum ucs_config_allow_list_mode_t::UInt32 begin
    UCS_CONFIG_ALLOW_LIST_ALLOW_ALL = 0
    UCS_CONFIG_ALLOW_LIST_ALLOW = 1
    UCS_CONFIG_ALLOW_LIST_NEGATE = 2
end

struct ucs_config_allow_list_t
    array::ucs_config_names_array_t
    mode::ucs_config_allow_list_mode_t
end

struct ucs_sock_addr
    addr::Ptr{sockaddr}
    addrlen::socklen_t
end

const ucs_sock_addr_t = ucs_sock_addr

struct ucs_log_component_config
    log_level::ucs_log_level_t
    name::NTuple{16, Cchar}
    file_filter::Ptr{Cchar}
end

const ucs_log_component_config_t = ucs_log_component_config

const ucp_tag_t = UInt64

struct ucp_tag_recv_info
    sender_tag::ucp_tag_t
    length::Csize_t
end

const ucp_tag_recv_info_t = ucp_tag_recv_info

mutable struct ucp_ep end

const ucp_ep_h = Ptr{ucp_ep}

struct ucp_am_recv_param
    recv_attr::UInt64
    reply_ep::ucp_ep_h
end

const ucp_am_recv_param_t = ucp_am_recv_param

mutable struct ucp_context end

const ucp_context_h = Ptr{ucp_context}

mutable struct ucp_config end

const ucp_config_t = ucp_config

mutable struct ucp_conn_request end

const ucp_conn_request_h = Ptr{ucp_conn_request}

mutable struct ucp_address end

const ucp_address_t = ucp_address

@cenum ucp_err_handling_mode_t::UInt32 begin
    UCP_ERR_HANDLING_MODE_NONE = 0
    UCP_ERR_HANDLING_MODE_PEER = 1
end

mutable struct ucp_rkey end

const ucp_rkey_h = Ptr{ucp_rkey}

mutable struct ucp_mem end

const ucp_mem_h = Ptr{ucp_mem}

mutable struct ucp_listener end

const ucp_listener_h = Ptr{ucp_listener}

struct ucp_mem_attr
    field_mask::UInt64
    address::Ptr{Cvoid}
    length::Csize_t
    mem_type::ucs_memory_type_t
end

const ucp_mem_attr_t = ucp_mem_attr

@cenum ucp_mem_attr_field::UInt32 begin
    UCP_MEM_ATTR_FIELD_ADDRESS = 1
    UCP_MEM_ATTR_FIELD_LENGTH = 2
    UCP_MEM_ATTR_FIELD_MEM_TYPE = 4
end

mutable struct ucp_worker end

const ucp_worker_h = Ptr{ucp_worker}

mutable struct ucp_recv_desc end

const ucp_tag_message_h = Ptr{ucp_recv_desc}

# typedef void ( * ucp_request_init_callback_t ) ( void * request )
const ucp_request_init_callback_t = Ptr{Cvoid}

# typedef void ( * ucp_request_cleanup_callback_t ) ( void * request )
const ucp_request_cleanup_callback_t = Ptr{Cvoid}

# typedef void ( * ucp_send_callback_t ) ( void * request , ucs_status_t status )
const ucp_send_callback_t = Ptr{Cvoid}

# typedef void ( * ucp_send_nbx_callback_t ) ( void * request , ucs_status_t status , void * user_data )
const ucp_send_nbx_callback_t = Ptr{Cvoid}

# typedef void ( * ucp_err_handler_cb_t ) ( void * arg , ucp_ep_h ep , ucs_status_t status )
const ucp_err_handler_cb_t = Ptr{Cvoid}

struct ucp_err_handler
    cb::ucp_err_handler_cb_t
    arg::Ptr{Cvoid}
end

const ucp_err_handler_t = ucp_err_handler

# typedef void ( * ucp_listener_accept_callback_t ) ( ucp_ep_h ep , void * arg )
const ucp_listener_accept_callback_t = Ptr{Cvoid}

# typedef void ( * ucp_listener_conn_callback_t ) ( ucp_conn_request_h conn_request , void * arg )
const ucp_listener_conn_callback_t = Ptr{Cvoid}

struct ucp_listener_conn_handler
    cb::ucp_listener_conn_callback_t
    arg::Ptr{Cvoid}
end

const ucp_listener_conn_handler_t = ucp_listener_conn_handler

# typedef void ( * ucp_stream_recv_callback_t ) ( void * request , ucs_status_t status , size_t length )
const ucp_stream_recv_callback_t = Ptr{Cvoid}

# typedef void ( * ucp_stream_recv_nbx_callback_t ) ( void * request , ucs_status_t status , size_t length , void * user_data )
const ucp_stream_recv_nbx_callback_t = Ptr{Cvoid}

# typedef void ( * ucp_tag_recv_callback_t ) ( void * request , ucs_status_t status , ucp_tag_recv_info_t * info )
const ucp_tag_recv_callback_t = Ptr{Cvoid}

# typedef void ( * ucp_tag_recv_nbx_callback_t ) ( void * request , ucs_status_t status , const ucp_tag_recv_info_t * tag_info , void * user_data )
const ucp_tag_recv_nbx_callback_t = Ptr{Cvoid}

# typedef void ( * ucp_am_recv_data_nbx_callback_t ) ( void * request , ucs_status_t status , size_t length , void * user_data )
const ucp_am_recv_data_nbx_callback_t = Ptr{Cvoid}

@cenum ucp_wakeup_event_types::UInt32 begin
    UCP_WAKEUP_RMA = 1
    UCP_WAKEUP_AMO = 2
    UCP_WAKEUP_TAG_SEND = 4
    UCP_WAKEUP_TAG_RECV = 8
    UCP_WAKEUP_TX = 1024
    UCP_WAKEUP_RX = 2048
    UCP_WAKEUP_EDGE = 65536
end

const ucp_wakeup_event_t = ucp_wakeup_event_types

# typedef ucs_status_t ( * ucp_am_callback_t ) ( void * arg , void * data , size_t length , ucp_ep_h reply_ep , unsigned flags )
const ucp_am_callback_t = Ptr{Cvoid}

# typedef ucs_status_t ( * ucp_am_recv_callback_t ) ( void * arg , const void * header , size_t header_length , void * data , size_t length , const ucp_am_recv_param_t * param )
const ucp_am_recv_callback_t = Ptr{Cvoid}

struct ucp_ep_params
    field_mask::UInt64
    address::Ptr{ucp_address_t}
    err_mode::ucp_err_handling_mode_t
    err_handler::ucp_err_handler_t
    user_data::Ptr{Cvoid}
    flags::Cuint
    sockaddr::ucs_sock_addr_t
    conn_request::ucp_conn_request_h
    name::Ptr{Cchar}
end

const ucp_ep_params_t = ucp_ep_params

struct ucp_listener_accept_handler
    cb::ucp_listener_accept_callback_t
    arg::Ptr{Cvoid}
end

const ucp_listener_accept_handler_t = ucp_listener_accept_handler

function ucp_request_is_completed(request)
    ccall((:ucp_request_is_completed, libucp), Cint, (Ptr{Cvoid},), request)
end

function ucp_request_release(request)
    ccall((:ucp_request_release, libucp), Cvoid, (Ptr{Cvoid},), request)
end

function ucp_ep_destroy(ep)
    ccall((:ucp_ep_destroy, libucp), Cvoid, (ucp_ep_h,), ep)
end

function ucp_disconnect_nb(ep)
    ccall((:ucp_disconnect_nb, libucp), ucs_status_ptr_t, (ucp_ep_h,), ep)
end

function ucp_request_test(request, info)
    ccall((:ucp_request_test, libucp), ucs_status_t, (Ptr{Cvoid}, Ptr{ucp_tag_recv_info_t}), request, info)
end

function ucp_ep_flush(ep)
    ccall((:ucp_ep_flush, libucp), ucs_status_t, (ucp_ep_h,), ep)
end

function ucp_worker_flush(worker)
    ccall((:ucp_worker_flush, libucp), ucs_status_t, (ucp_worker_h,), worker)
end

function ucp_put(ep, buffer, length, remote_addr, rkey)
    ccall((:ucp_put, libucp), ucs_status_t, (ucp_ep_h, Ptr{Cvoid}, Csize_t, UInt64, ucp_rkey_h), ep, buffer, length, remote_addr, rkey)
end

function ucp_get(ep, buffer, length, remote_addr, rkey)
    ccall((:ucp_get, libucp), ucs_status_t, (ucp_ep_h, Ptr{Cvoid}, Csize_t, UInt64, ucp_rkey_h), ep, buffer, length, remote_addr, rkey)
end

function ucp_atomic_add32(ep, add, remote_addr, rkey)
    ccall((:ucp_atomic_add32, libucp), ucs_status_t, (ucp_ep_h, UInt32, UInt64, ucp_rkey_h), ep, add, remote_addr, rkey)
end

function ucp_atomic_add64(ep, add, remote_addr, rkey)
    ccall((:ucp_atomic_add64, libucp), ucs_status_t, (ucp_ep_h, UInt64, UInt64, ucp_rkey_h), ep, add, remote_addr, rkey)
end

function ucp_atomic_fadd32(ep, add, remote_addr, rkey, result)
    ccall((:ucp_atomic_fadd32, libucp), ucs_status_t, (ucp_ep_h, UInt32, UInt64, ucp_rkey_h, Ptr{UInt32}), ep, add, remote_addr, rkey, result)
end

function ucp_atomic_fadd64(ep, add, remote_addr, rkey, result)
    ccall((:ucp_atomic_fadd64, libucp), ucs_status_t, (ucp_ep_h, UInt64, UInt64, ucp_rkey_h, Ptr{UInt64}), ep, add, remote_addr, rkey, result)
end

function ucp_atomic_swap32(ep, swap, remote_addr, rkey, result)
    ccall((:ucp_atomic_swap32, libucp), ucs_status_t, (ucp_ep_h, UInt32, UInt64, ucp_rkey_h, Ptr{UInt32}), ep, swap, remote_addr, rkey, result)
end

function ucp_atomic_swap64(ep, swap, remote_addr, rkey, result)
    ccall((:ucp_atomic_swap64, libucp), ucs_status_t, (ucp_ep_h, UInt64, UInt64, ucp_rkey_h, Ptr{UInt64}), ep, swap, remote_addr, rkey, result)
end

function ucp_atomic_cswap32(ep, compare, swap, remote_addr, rkey, result)
    ccall((:ucp_atomic_cswap32, libucp), ucs_status_t, (ucp_ep_h, UInt32, UInt32, UInt64, ucp_rkey_h, Ptr{UInt32}), ep, compare, swap, remote_addr, rkey, result)
end

function ucp_atomic_cswap64(ep, compare, swap, remote_addr, rkey, result)
    ccall((:ucp_atomic_cswap64, libucp), ucs_status_t, (ucp_ep_h, UInt64, UInt64, UInt64, ucp_rkey_h, Ptr{UInt64}), ep, compare, swap, remote_addr, rkey, result)
end

function ucp_ep_modify_nb(ep, params)
    ccall((:ucp_ep_modify_nb, libucp), ucs_status_ptr_t, (ucp_ep_h, Ptr{ucp_ep_params_t}), ep, params)
end

@cenum ucs_thread_mode_t::UInt32 begin
    UCS_THREAD_MODE_SINGLE = 0
    UCS_THREAD_MODE_SERIALIZED = 1
    UCS_THREAD_MODE_MULTI = 2
    UCS_THREAD_MODE_LAST = 3
end

function ucs_cpu_is_set(cpu, cpusetp)
    ccall((:ucs_cpu_is_set, libucp), Cint, (Cint, Ptr{ucs_cpu_set_t}), cpu, cpusetp)
end

function ucs_cpu_set_find_lcs(cpu_mask)
    ccall((:ucs_cpu_set_find_lcs, libucp), Cint, (Ptr{ucs_cpu_set_t},), cpu_mask)
end

@cenum ucp_params_field::UInt32 begin
    UCP_PARAM_FIELD_FEATURES = 1
    UCP_PARAM_FIELD_REQUEST_SIZE = 2
    UCP_PARAM_FIELD_REQUEST_INIT = 4
    UCP_PARAM_FIELD_REQUEST_CLEANUP = 8
    UCP_PARAM_FIELD_TAG_SENDER_MASK = 16
    UCP_PARAM_FIELD_MT_WORKERS_SHARED = 32
    UCP_PARAM_FIELD_ESTIMATED_NUM_EPS = 64
    UCP_PARAM_FIELD_ESTIMATED_NUM_PPN = 128
    UCP_PARAM_FIELD_NAME = 256
end

@cenum ucp_feature::UInt32 begin
    UCP_FEATURE_TAG = 1
    UCP_FEATURE_RMA = 2
    UCP_FEATURE_AMO32 = 4
    UCP_FEATURE_AMO64 = 8
    UCP_FEATURE_WAKEUP = 16
    UCP_FEATURE_STREAM = 32
    UCP_FEATURE_AM = 64
end

@cenum ucp_worker_params_field::UInt32 begin
    UCP_WORKER_PARAM_FIELD_THREAD_MODE = 1
    UCP_WORKER_PARAM_FIELD_CPU_MASK = 2
    UCP_WORKER_PARAM_FIELD_EVENTS = 4
    UCP_WORKER_PARAM_FIELD_USER_DATA = 8
    UCP_WORKER_PARAM_FIELD_EVENT_FD = 16
    UCP_WORKER_PARAM_FIELD_FLAGS = 32
    UCP_WORKER_PARAM_FIELD_NAME = 64
end

@cenum ucp_worker_flags_t::UInt32 begin
    UCP_WORKER_FLAG_IGNORE_REQUEST_LEAK = 1
end

@cenum ucp_listener_params_field::UInt32 begin
    UCP_LISTENER_PARAM_FIELD_SOCK_ADDR = 1
    UCP_LISTENER_PARAM_FIELD_ACCEPT_HANDLER = 2
    UCP_LISTENER_PARAM_FIELD_CONN_HANDLER = 4
end

@cenum ucp_worker_address_flags_t::UInt32 begin
    UCP_WORKER_ADDRESS_FLAG_NET_ONLY = 1
end

@cenum ucp_ep_params_field::UInt32 begin
    UCP_EP_PARAM_FIELD_REMOTE_ADDRESS = 1
    UCP_EP_PARAM_FIELD_ERR_HANDLING_MODE = 2
    UCP_EP_PARAM_FIELD_ERR_HANDLER = 4
    UCP_EP_PARAM_FIELD_USER_DATA = 8
    UCP_EP_PARAM_FIELD_SOCK_ADDR = 16
    UCP_EP_PARAM_FIELD_FLAGS = 32
    UCP_EP_PARAM_FIELD_CONN_REQUEST = 64
    UCP_EP_PARAM_FIELD_NAME = 128
end

@cenum ucp_ep_params_flags_field::UInt32 begin
    UCP_EP_PARAMS_FLAGS_CLIENT_SERVER = 1
    UCP_EP_PARAMS_FLAGS_NO_LOOPBACK = 2
end

@cenum ucp_ep_close_flags_t::UInt32 begin
    UCP_EP_CLOSE_FLAG_FORCE = 1
end

@cenum ucp_ep_close_mode::UInt32 begin
    UCP_EP_CLOSE_MODE_FORCE = 0
    UCP_EP_CLOSE_MODE_FLUSH = 1
end

@cenum ucp_ep_perf_param_field::UInt32 begin
    UCP_EP_PERF_PARAM_FIELD_MESSAGE_SIZE = 1
end

const ucp_ep_perf_param_field_t = ucp_ep_perf_param_field

@cenum ucp_ep_perf_attr_field::UInt32 begin
    UCP_EP_PERF_ATTR_FIELD_ESTIMATED_TIME = 1
end

const ucp_ep_perf_attr_field_t = ucp_ep_perf_attr_field

@cenum ucp_mem_map_params_field::UInt32 begin
    UCP_MEM_MAP_PARAM_FIELD_ADDRESS = 1
    UCP_MEM_MAP_PARAM_FIELD_LENGTH = 2
    UCP_MEM_MAP_PARAM_FIELD_FLAGS = 4
    UCP_MEM_MAP_PARAM_FIELD_PROT = 8
    UCP_MEM_MAP_PARAM_FIELD_MEMORY_TYPE = 16
end

@cenum ucp_mem_advise_params_field::UInt32 begin
    UCP_MEM_ADVISE_PARAM_FIELD_ADDRESS = 1
    UCP_MEM_ADVISE_PARAM_FIELD_LENGTH = 2
    UCP_MEM_ADVISE_PARAM_FIELD_ADVICE = 4
end

@cenum ucp_lib_attr_field::UInt32 begin
    UCP_LIB_ATTR_FIELD_MAX_THREAD_LEVEL = 1
end

@cenum ucp_context_attr_field::UInt32 begin
    UCP_ATTR_FIELD_REQUEST_SIZE = 1
    UCP_ATTR_FIELD_THREAD_MODE = 2
    UCP_ATTR_FIELD_MEMORY_TYPES = 4
    UCP_ATTR_FIELD_NAME = 8
end

@cenum ucp_worker_attr_field::UInt32 begin
    UCP_WORKER_ATTR_FIELD_THREAD_MODE = 1
    UCP_WORKER_ATTR_FIELD_ADDRESS = 2
    UCP_WORKER_ATTR_FIELD_ADDRESS_FLAGS = 4
    UCP_WORKER_ATTR_FIELD_MAX_AM_HEADER = 8
    UCP_WORKER_ATTR_FIELD_NAME = 16
    UCP_WORKER_ATTR_FIELD_MAX_INFO_STRING = 32
end

@cenum ucp_listener_attr_field::UInt32 begin
    UCP_LISTENER_ATTR_FIELD_SOCKADDR = 1
end

@cenum ucp_conn_request_attr_field::UInt32 begin
    UCP_CONN_REQUEST_ATTR_FIELD_CLIENT_ADDR = 1
end

@cenum ucp_dt_type::UInt32 begin
    UCP_DATATYPE_CONTIG = 0
    UCP_DATATYPE_STRIDED = 1
    UCP_DATATYPE_IOV = 2
    UCP_DATATYPE_GENERIC = 7
    UCP_DATATYPE_SHIFT = 3
    UCP_DATATYPE_CLASS_MASK = 7
end

@cenum __JL_Ctag_34::UInt32 begin
    UCP_MEM_MAP_NONBLOCK = 1
    UCP_MEM_MAP_ALLOCATE = 2
    UCP_MEM_MAP_FIXED = 4
end

@cenum __JL_Ctag_35::UInt32 begin
    UCP_MEM_MAP_PROT_LOCAL_READ = 1
    UCP_MEM_MAP_PROT_LOCAL_WRITE = 2
    UCP_MEM_MAP_PROT_REMOTE_READ = 256
    UCP_MEM_MAP_PROT_REMOTE_WRITE = 512
end

@cenum ucp_am_cb_flags::UInt32 begin
    UCP_AM_FLAG_WHOLE_MSG = 1
    UCP_AM_FLAG_PERSISTENT_DATA = 2
end

@cenum ucp_send_am_flags::UInt32 begin
    UCP_AM_SEND_FLAG_REPLY = 1
    UCP_AM_SEND_FLAG_EAGER = 2
    UCP_AM_SEND_FLAG_RNDV = 4
    UCP_AM_SEND_REPLY = 1
end

@cenum ucp_cb_param_flags::UInt32 begin
    UCP_CB_PARAM_FLAG_DATA = 1
end

@cenum ucp_atomic_post_op_t::UInt32 begin
    UCP_ATOMIC_POST_OP_ADD = 0
    UCP_ATOMIC_POST_OP_AND = 1
    UCP_ATOMIC_POST_OP_OR = 2
    UCP_ATOMIC_POST_OP_XOR = 3
    UCP_ATOMIC_POST_OP_LAST = 4
end

@cenum ucp_atomic_fetch_op_t::UInt32 begin
    UCP_ATOMIC_FETCH_OP_FADD = 0
    UCP_ATOMIC_FETCH_OP_SWAP = 1
    UCP_ATOMIC_FETCH_OP_CSWAP = 2
    UCP_ATOMIC_FETCH_OP_FAND = 3
    UCP_ATOMIC_FETCH_OP_FOR = 4
    UCP_ATOMIC_FETCH_OP_FXOR = 5
    UCP_ATOMIC_FETCH_OP_LAST = 6
end

@cenum ucp_atomic_op_t::UInt32 begin
    UCP_ATOMIC_OP_ADD = 0
    UCP_ATOMIC_OP_SWAP = 1
    UCP_ATOMIC_OP_CSWAP = 2
    UCP_ATOMIC_OP_AND = 3
    UCP_ATOMIC_OP_OR = 4
    UCP_ATOMIC_OP_XOR = 5
    UCP_ATOMIC_OP_LAST = 6
end

@cenum ucp_stream_recv_flags_t::UInt32 begin
    UCP_STREAM_RECV_FLAG_WAITALL = 1
end

@cenum ucp_op_attr_t::UInt32 begin
    UCP_OP_ATTR_FIELD_REQUEST = 1
    UCP_OP_ATTR_FIELD_CALLBACK = 2
    UCP_OP_ATTR_FIELD_USER_DATA = 4
    UCP_OP_ATTR_FIELD_DATATYPE = 8
    UCP_OP_ATTR_FIELD_FLAGS = 16
    UCP_OP_ATTR_FIELD_REPLY_BUFFER = 32
    UCP_OP_ATTR_FIELD_MEMORY_TYPE = 64
    UCP_OP_ATTR_FIELD_RECV_INFO = 128
    UCP_OP_ATTR_FLAG_NO_IMM_CMPL = 65536
    UCP_OP_ATTR_FLAG_FAST_CMPL = 131072
    UCP_OP_ATTR_FLAG_FORCE_IMM_CMPL = 262144
end

@cenum ucp_req_attr_field::UInt32 begin
    UCP_REQUEST_ATTR_FIELD_INFO_STRING = 1
    UCP_REQUEST_ATTR_FIELD_INFO_STRING_SIZE = 2
    UCP_REQUEST_ATTR_FIELD_STATUS = 4
    UCP_REQUEST_ATTR_FIELD_MEM_TYPE = 8
end

@cenum ucp_am_recv_attr_t::UInt32 begin
    UCP_AM_RECV_ATTR_FIELD_REPLY_EP = 1
    UCP_AM_RECV_ATTR_FLAG_DATA = 65536
    UCP_AM_RECV_ATTR_FLAG_RNDV = 131072
end

@cenum ucp_am_handler_param_field::UInt32 begin
    UCP_AM_HANDLER_PARAM_FIELD_ID = 1
    UCP_AM_HANDLER_PARAM_FIELD_FLAGS = 2
    UCP_AM_HANDLER_PARAM_FIELD_CB = 4
    UCP_AM_HANDLER_PARAM_FIELD_ARG = 8
end

struct ucp_dt_iov
    buffer::Ptr{Cvoid}
    length::Csize_t
end

const ucp_dt_iov_t = ucp_dt_iov

struct ucp_generic_dt_ops
    start_pack::Ptr{Cvoid}
    start_unpack::Ptr{Cvoid}
    packed_size::Ptr{Cvoid}
    pack::Ptr{Cvoid}
    unpack::Ptr{Cvoid}
    finish::Ptr{Cvoid}
end

const ucp_generic_dt_ops_t = ucp_generic_dt_ops

struct ucp_params
    field_mask::UInt64
    features::UInt64
    request_size::Csize_t
    request_init::ucp_request_init_callback_t
    request_cleanup::ucp_request_cleanup_callback_t
    tag_sender_mask::UInt64
    mt_workers_shared::Cint
    estimated_num_eps::Csize_t
    estimated_num_ppn::Csize_t
    name::Ptr{Cchar}
end

const ucp_params_t = ucp_params

struct ucp_lib_attr
    field_mask::UInt64
    max_thread_level::ucs_thread_mode_t
end

const ucp_lib_attr_t = ucp_lib_attr

struct ucp_context_attr
    field_mask::UInt64
    request_size::Csize_t
    thread_mode::ucs_thread_mode_t
    memory_types::UInt64
    name::NTuple{32, Cchar}
end

const ucp_context_attr_t = ucp_context_attr

struct ucp_worker_attr
    field_mask::UInt64
    thread_mode::ucs_thread_mode_t
    address_flags::UInt32
    address::Ptr{ucp_address_t}
    address_length::Csize_t
    max_am_header::Csize_t
    name::NTuple{32, Cchar}
    max_debug_string::Csize_t
end

const ucp_worker_attr_t = ucp_worker_attr

struct ucp_worker_params
    field_mask::UInt64
    thread_mode::ucs_thread_mode_t
    cpu_mask::ucs_cpu_set_t
    events::Cuint
    user_data::Ptr{Cvoid}
    event_fd::Cint
    flags::UInt64
    name::Ptr{Cchar}
end

const ucp_worker_params_t = ucp_worker_params

struct ucp_ep_evaluate_perf_param_t
    field_mask::UInt64
    message_size::Csize_t
end

struct ucp_ep_evaluate_perf_attr_t
    field_mask::UInt64
    estimated_time::Cdouble
end

struct sockaddr_storage
    ss_family::sa_family_t
    __ss_align::Culong
    __ss_padding::NTuple{112, Cchar}
end

struct ucp_listener_attr
    field_mask::UInt64
    sockaddr::sockaddr_storage
end

const ucp_listener_attr_t = ucp_listener_attr

struct ucp_conn_request_attr
    field_mask::UInt64
    client_address::sockaddr_storage
end

const ucp_conn_request_attr_t = ucp_conn_request_attr

struct ucp_listener_params
    field_mask::UInt64
    sockaddr::ucs_sock_addr_t
    accept_handler::ucp_listener_accept_handler_t
    conn_handler::ucp_listener_conn_handler_t
end

const ucp_listener_params_t = ucp_listener_params

struct ucp_stream_poll_ep
    ep::ucp_ep_h
    user_data::Ptr{Cvoid}
    flags::Cuint
    reserved::NTuple{16, UInt8}
end

const ucp_stream_poll_ep_t = ucp_stream_poll_ep

struct ucp_mem_map_params
    field_mask::UInt64
    address::Ptr{Cvoid}
    length::Csize_t
    flags::Cuint
    prot::Cuint
    memory_type::ucs_memory_type_t
end

const ucp_mem_map_params_t = ucp_mem_map_params

struct __JL_Ctag_47
    data::NTuple{8, UInt8}
end

function Base.getproperty(x::Ptr{__JL_Ctag_47}, f::Symbol)
    f === :send && return Ptr{ucp_send_nbx_callback_t}(x + 0)
    f === :recv && return Ptr{ucp_tag_recv_nbx_callback_t}(x + 0)
    f === :recv_stream && return Ptr{ucp_stream_recv_nbx_callback_t}(x + 0)
    f === :recv_am && return Ptr{ucp_am_recv_data_nbx_callback_t}(x + 0)
    return getfield(x, f)
end

function Base.getproperty(x::__JL_Ctag_47, f::Symbol)
    r = Ref{__JL_Ctag_47}(x)
    ptr = Base.unsafe_convert(Ptr{__JL_Ctag_47}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{__JL_Ctag_47}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

struct __JL_Ctag_48
    data::NTuple{8, UInt8}
end

function Base.getproperty(x::Ptr{__JL_Ctag_48}, f::Symbol)
    f === :length && return Ptr{Ptr{Csize_t}}(x + 0)
    f === :tag_info && return Ptr{Ptr{ucp_tag_recv_info_t}}(x + 0)
    return getfield(x, f)
end

function Base.getproperty(x::__JL_Ctag_48, f::Symbol)
    r = Ref{__JL_Ctag_48}(x)
    ptr = Base.unsafe_convert(Ptr{__JL_Ctag_48}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{__JL_Ctag_48}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

struct ucp_request_param_t
    op_attr_mask::UInt32
    flags::UInt32
    request::Ptr{Cvoid}
    cb::__JL_Ctag_47
    datatype::ucp_datatype_t
    user_data::Ptr{Cvoid}
    reply_buffer::Ptr{Cvoid}
    memory_type::ucs_memory_type_t
    recv_info::__JL_Ctag_48
end

struct ucp_request_attr_t
    field_mask::UInt64
    debug_string::Ptr{Cchar}
    debug_string_size::Csize_t
    status::ucs_status_t
    mem_type::ucs_memory_type_t
end

struct ucp_am_handler_param
    field_mask::UInt64
    id::Cuint
    flags::UInt32
    cb::ucp_am_recv_callback_t
    arg::Ptr{Cvoid}
end

const ucp_am_handler_param_t = ucp_am_handler_param

function ucp_lib_query(attr)
    ccall((:ucp_lib_query, libucp), ucs_status_t, (Ptr{ucp_lib_attr_t},), attr)
end

function ucp_config_read(env_prefix, filename, config_p)
    ccall((:ucp_config_read, libucp), ucs_status_t, (Ptr{Cchar}, Ptr{Cchar}, Ptr{Ptr{ucp_config_t}}), env_prefix, filename, config_p)
end

function ucp_config_release(config)
    ccall((:ucp_config_release, libucp), Cvoid, (Ptr{ucp_config_t},), config)
end

function ucp_config_modify(config, name, value)
    ccall((:ucp_config_modify, libucp), ucs_status_t, (Ptr{ucp_config_t}, Ptr{Cchar}, Ptr{Cchar}), config, name, value)
end

function ucp_config_print(config, stream, title, print_flags)
    ccall((:ucp_config_print, libucp), Cvoid, (Ptr{ucp_config_t}, Ptr{FILE}, Ptr{Cchar}, ucs_config_print_flags_t), config, stream, title, print_flags)
end

function ucp_get_version(major_version, minor_version, release_number)
    ccall((:ucp_get_version, libucp), Cvoid, (Ptr{Cuint}, Ptr{Cuint}, Ptr{Cuint}), major_version, minor_version, release_number)
end

function ucp_get_version_string()
    ccall((:ucp_get_version_string, libucp), Ptr{Cchar}, ())
end

function ucp_init_version(api_major_version, api_minor_version, params, config, context_p)
    ccall((:ucp_init_version, libucp), ucs_status_t, (Cuint, Cuint, Ptr{ucp_params_t}, Ptr{ucp_config_t}, Ptr{ucp_context_h}), api_major_version, api_minor_version, params, config, context_p)
end

function ucp_init(params, config, context_p)
    ccall((:ucp_init, libucp), ucs_status_t, (Ptr{ucp_params_t}, Ptr{ucp_config_t}, Ptr{ucp_context_h}), params, config, context_p)
end

function ucp_cleanup(context_p)
    ccall((:ucp_cleanup, libucp), Cvoid, (ucp_context_h,), context_p)
end

function ucp_context_query(context_p, attr)
    ccall((:ucp_context_query, libucp), ucs_status_t, (ucp_context_h, Ptr{ucp_context_attr_t}), context_p, attr)
end

function ucp_context_print_info(context, stream)
    ccall((:ucp_context_print_info, libucp), Cvoid, (ucp_context_h, Ptr{FILE}), context, stream)
end

function ucp_worker_create(context, params, worker_p)
    ccall((:ucp_worker_create, libucp), ucs_status_t, (ucp_context_h, Ptr{ucp_worker_params_t}, Ptr{ucp_worker_h}), context, params, worker_p)
end

function ucp_worker_destroy(worker)
    ccall((:ucp_worker_destroy, libucp), Cvoid, (ucp_worker_h,), worker)
end

function ucp_worker_query(worker, attr)
    ccall((:ucp_worker_query, libucp), ucs_status_t, (ucp_worker_h, Ptr{ucp_worker_attr_t}), worker, attr)
end

function ucp_worker_print_info(worker, stream)
    ccall((:ucp_worker_print_info, libucp), Cvoid, (ucp_worker_h, Ptr{FILE}), worker, stream)
end

function ucp_worker_get_address(worker, address_p, address_length_p)
    ccall((:ucp_worker_get_address, libucp), ucs_status_t, (ucp_worker_h, Ptr{Ptr{ucp_address_t}}, Ptr{Csize_t}), worker, address_p, address_length_p)
end

function ucp_worker_release_address(worker, address)
    ccall((:ucp_worker_release_address, libucp), Cvoid, (ucp_worker_h, Ptr{ucp_address_t}), worker, address)
end

function ucp_worker_progress(worker)
    ccall((:ucp_worker_progress, libucp), Cuint, (ucp_worker_h,), worker)
end

function ucp_stream_worker_poll(worker, poll_eps, max_eps, flags)
    ccall((:ucp_stream_worker_poll, libucp), Cssize_t, (ucp_worker_h, Ptr{ucp_stream_poll_ep_t}, Csize_t, Cuint), worker, poll_eps, max_eps, flags)
end

function ucp_worker_get_efd(worker, fd)
    ccall((:ucp_worker_get_efd, libucp), ucs_status_t, (ucp_worker_h, Ptr{Cint}), worker, fd)
end

function ucp_worker_wait(worker)
    ccall((:ucp_worker_wait, libucp), ucs_status_t, (ucp_worker_h,), worker)
end

function ucp_worker_wait_mem(worker, address)
    ccall((:ucp_worker_wait_mem, libucp), Cvoid, (ucp_worker_h, Ptr{Cvoid}), worker, address)
end

function ucp_worker_arm(worker)
    ccall((:ucp_worker_arm, libucp), ucs_status_t, (ucp_worker_h,), worker)
end

function ucp_worker_signal(worker)
    ccall((:ucp_worker_signal, libucp), ucs_status_t, (ucp_worker_h,), worker)
end

function ucp_listener_create(worker, params, listener_p)
    ccall((:ucp_listener_create, libucp), ucs_status_t, (ucp_worker_h, Ptr{ucp_listener_params_t}, Ptr{ucp_listener_h}), worker, params, listener_p)
end

function ucp_listener_destroy(listener)
    ccall((:ucp_listener_destroy, libucp), Cvoid, (ucp_listener_h,), listener)
end

function ucp_listener_query(listener, attr)
    ccall((:ucp_listener_query, libucp), ucs_status_t, (ucp_listener_h, Ptr{ucp_listener_attr_t}), listener, attr)
end

function ucp_conn_request_query(conn_request, attr)
    ccall((:ucp_conn_request_query, libucp), ucs_status_t, (ucp_conn_request_h, Ptr{ucp_conn_request_attr_t}), conn_request, attr)
end

function ucp_request_query(request, attr)
    ccall((:ucp_request_query, libucp), ucs_status_t, (Ptr{Cvoid}, Ptr{ucp_request_attr_t}), request, attr)
end

function ucp_ep_create(worker, params, ep_p)
    ccall((:ucp_ep_create, libucp), ucs_status_t, (ucp_worker_h, Ptr{ucp_ep_params_t}, Ptr{ucp_ep_h}), worker, params, ep_p)
end

function ucp_ep_close_nb(ep, mode)
    ccall((:ucp_ep_close_nb, libucp), ucs_status_ptr_t, (ucp_ep_h, Cuint), ep, mode)
end

function ucp_ep_close_nbx(ep, param)
    ccall((:ucp_ep_close_nbx, libucp), ucs_status_ptr_t, (ucp_ep_h, Ptr{ucp_request_param_t}), ep, param)
end

function ucp_listener_reject(listener, conn_request)
    ccall((:ucp_listener_reject, libucp), ucs_status_t, (ucp_listener_h, ucp_conn_request_h), listener, conn_request)
end

function ucp_ep_print_info(ep, stream)
    ccall((:ucp_ep_print_info, libucp), Cvoid, (ucp_ep_h, Ptr{FILE}), ep, stream)
end

function ucp_ep_flush_nb(ep, flags, cb)
    ccall((:ucp_ep_flush_nb, libucp), ucs_status_ptr_t, (ucp_ep_h, Cuint, ucp_send_callback_t), ep, flags, cb)
end

function ucp_ep_flush_nbx(ep, param)
    ccall((:ucp_ep_flush_nbx, libucp), ucs_status_ptr_t, (ucp_ep_h, Ptr{ucp_request_param_t}), ep, param)
end

function ucp_ep_evaluate_perf(ep, param, attr)
    ccall((:ucp_ep_evaluate_perf, libucp), ucs_status_t, (ucp_ep_h, Ptr{ucp_ep_evaluate_perf_param_t}, Ptr{ucp_ep_evaluate_perf_attr_t}), ep, param, attr)
end

function ucp_mem_map(context, params, memh_p)
    ccall((:ucp_mem_map, libucp), ucs_status_t, (ucp_context_h, Ptr{ucp_mem_map_params_t}, Ptr{ucp_mem_h}), context, params, memh_p)
end

function ucp_mem_unmap(context, memh)
    ccall((:ucp_mem_unmap, libucp), ucs_status_t, (ucp_context_h, ucp_mem_h), context, memh)
end

function ucp_mem_query(memh, attr)
    ccall((:ucp_mem_query, libucp), ucs_status_t, (ucp_mem_h, Ptr{ucp_mem_attr_t}), memh, attr)
end

function ucp_mem_print_info(mem_size, context, stream)
    ccall((:ucp_mem_print_info, libucp), Cvoid, (Ptr{Cchar}, ucp_context_h, Ptr{FILE}), mem_size, context, stream)
end

@cenum ucp_mem_advice::UInt32 begin
    UCP_MADV_NORMAL = 0
    UCP_MADV_WILLNEED = 1
end

const ucp_mem_advice_t = ucp_mem_advice

struct ucp_mem_advise_params
    field_mask::UInt64
    address::Ptr{Cvoid}
    length::Csize_t
    advice::ucp_mem_advice_t
end

const ucp_mem_advise_params_t = ucp_mem_advise_params

function ucp_mem_advise(context, memh, params)
    ccall((:ucp_mem_advise, libucp), ucs_status_t, (ucp_context_h, ucp_mem_h, Ptr{ucp_mem_advise_params_t}), context, memh, params)
end

function ucp_rkey_pack(context, memh, rkey_buffer_p, size_p)
    ccall((:ucp_rkey_pack, libucp), ucs_status_t, (ucp_context_h, ucp_mem_h, Ptr{Ptr{Cvoid}}, Ptr{Csize_t}), context, memh, rkey_buffer_p, size_p)
end

function ucp_rkey_buffer_release(rkey_buffer)
    ccall((:ucp_rkey_buffer_release, libucp), Cvoid, (Ptr{Cvoid},), rkey_buffer)
end

function ucp_ep_rkey_unpack(ep, rkey_buffer, rkey_p)
    ccall((:ucp_ep_rkey_unpack, libucp), ucs_status_t, (ucp_ep_h, Ptr{Cvoid}, Ptr{ucp_rkey_h}), ep, rkey_buffer, rkey_p)
end

function ucp_rkey_ptr(rkey, raddr, addr_p)
    ccall((:ucp_rkey_ptr, libucp), ucs_status_t, (ucp_rkey_h, UInt64, Ptr{Ptr{Cvoid}}), rkey, raddr, addr_p)
end

function ucp_rkey_destroy(rkey)
    ccall((:ucp_rkey_destroy, libucp), Cvoid, (ucp_rkey_h,), rkey)
end

function ucp_worker_set_am_handler(worker, id, cb, arg, flags)
    ccall((:ucp_worker_set_am_handler, libucp), ucs_status_t, (ucp_worker_h, UInt16, ucp_am_callback_t, Ptr{Cvoid}, UInt32), worker, id, cb, arg, flags)
end

function ucp_worker_set_am_recv_handler(worker, param)
    ccall((:ucp_worker_set_am_recv_handler, libucp), ucs_status_t, (ucp_worker_h, Ptr{ucp_am_handler_param_t}), worker, param)
end

function ucp_am_send_nb(ep, id, buffer, count, datatype, cb, flags)
    ccall((:ucp_am_send_nb, libucp), ucs_status_ptr_t, (ucp_ep_h, UInt16, Ptr{Cvoid}, Csize_t, ucp_datatype_t, ucp_send_callback_t, Cuint), ep, id, buffer, count, datatype, cb, flags)
end

function ucp_am_send_nbx(ep, id, header, header_length, buffer, count, param)
    ccall((:ucp_am_send_nbx, libucp), ucs_status_ptr_t, (ucp_ep_h, Cuint, Ptr{Cvoid}, Csize_t, Ptr{Cvoid}, Csize_t, Ptr{ucp_request_param_t}), ep, id, header, header_length, buffer, count, param)
end

function ucp_am_recv_data_nbx(worker, data_desc, buffer, count, param)
    ccall((:ucp_am_recv_data_nbx, libucp), ucs_status_ptr_t, (ucp_worker_h, Ptr{Cvoid}, Ptr{Cvoid}, Csize_t, Ptr{ucp_request_param_t}), worker, data_desc, buffer, count, param)
end

function ucp_am_data_release(worker, data)
    ccall((:ucp_am_data_release, libucp), Cvoid, (ucp_worker_h, Ptr{Cvoid}), worker, data)
end

function ucp_stream_send_nb(ep, buffer, count, datatype, cb, flags)
    ccall((:ucp_stream_send_nb, libucp), ucs_status_ptr_t, (ucp_ep_h, Ptr{Cvoid}, Csize_t, ucp_datatype_t, ucp_send_callback_t, Cuint), ep, buffer, count, datatype, cb, flags)
end

function ucp_stream_send_nbx(ep, buffer, count, param)
    ccall((:ucp_stream_send_nbx, libucp), ucs_status_ptr_t, (ucp_ep_h, Ptr{Cvoid}, Csize_t, Ptr{ucp_request_param_t}), ep, buffer, count, param)
end

function ucp_tag_send_nb(ep, buffer, count, datatype, tag, cb)
    ccall((:ucp_tag_send_nb, libucp), ucs_status_ptr_t, (ucp_ep_h, Ptr{Cvoid}, Csize_t, ucp_datatype_t, ucp_tag_t, ucp_send_callback_t), ep, buffer, count, datatype, tag, cb)
end

function ucp_tag_send_nbr(ep, buffer, count, datatype, tag, req)
    ccall((:ucp_tag_send_nbr, libucp), ucs_status_t, (ucp_ep_h, Ptr{Cvoid}, Csize_t, ucp_datatype_t, ucp_tag_t, Ptr{Cvoid}), ep, buffer, count, datatype, tag, req)
end

function ucp_tag_send_sync_nb(ep, buffer, count, datatype, tag, cb)
    ccall((:ucp_tag_send_sync_nb, libucp), ucs_status_ptr_t, (ucp_ep_h, Ptr{Cvoid}, Csize_t, ucp_datatype_t, ucp_tag_t, ucp_send_callback_t), ep, buffer, count, datatype, tag, cb)
end

function ucp_tag_send_nbx(ep, buffer, count, tag, param)
    ccall((:ucp_tag_send_nbx, libucp), ucs_status_ptr_t, (ucp_ep_h, Ptr{Cvoid}, Csize_t, ucp_tag_t, Ptr{ucp_request_param_t}), ep, buffer, count, tag, param)
end

function ucp_tag_send_sync_nbx(ep, buffer, count, tag, param)
    ccall((:ucp_tag_send_sync_nbx, libucp), ucs_status_ptr_t, (ucp_ep_h, Ptr{Cvoid}, Csize_t, ucp_tag_t, Ptr{ucp_request_param_t}), ep, buffer, count, tag, param)
end

function ucp_stream_recv_nb(ep, buffer, count, datatype, cb, length, flags)
    ccall((:ucp_stream_recv_nb, libucp), ucs_status_ptr_t, (ucp_ep_h, Ptr{Cvoid}, Csize_t, ucp_datatype_t, ucp_stream_recv_callback_t, Ptr{Csize_t}, Cuint), ep, buffer, count, datatype, cb, length, flags)
end

function ucp_stream_recv_nbx(ep, buffer, count, length, param)
    ccall((:ucp_stream_recv_nbx, libucp), ucs_status_ptr_t, (ucp_ep_h, Ptr{Cvoid}, Csize_t, Ptr{Csize_t}, Ptr{ucp_request_param_t}), ep, buffer, count, length, param)
end

function ucp_stream_recv_data_nb(ep, length)
    ccall((:ucp_stream_recv_data_nb, libucp), ucs_status_ptr_t, (ucp_ep_h, Ptr{Csize_t}), ep, length)
end

function ucp_tag_recv_nb(worker, buffer, count, datatype, tag, tag_mask, cb)
    ccall((:ucp_tag_recv_nb, libucp), ucs_status_ptr_t, (ucp_worker_h, Ptr{Cvoid}, Csize_t, ucp_datatype_t, ucp_tag_t, ucp_tag_t, ucp_tag_recv_callback_t), worker, buffer, count, datatype, tag, tag_mask, cb)
end

function ucp_tag_recv_nbr(worker, buffer, count, datatype, tag, tag_mask, req)
    ccall((:ucp_tag_recv_nbr, libucp), ucs_status_t, (ucp_worker_h, Ptr{Cvoid}, Csize_t, ucp_datatype_t, ucp_tag_t, ucp_tag_t, Ptr{Cvoid}), worker, buffer, count, datatype, tag, tag_mask, req)
end

function ucp_tag_recv_nbx(worker, buffer, count, tag, tag_mask, param)
    ccall((:ucp_tag_recv_nbx, libucp), ucs_status_ptr_t, (ucp_worker_h, Ptr{Cvoid}, Csize_t, ucp_tag_t, ucp_tag_t, Ptr{ucp_request_param_t}), worker, buffer, count, tag, tag_mask, param)
end

function ucp_tag_probe_nb(worker, tag, tag_mask, remove, info)
    ccall((:ucp_tag_probe_nb, libucp), ucp_tag_message_h, (ucp_worker_h, ucp_tag_t, ucp_tag_t, Cint, Ptr{ucp_tag_recv_info_t}), worker, tag, tag_mask, remove, info)
end

function ucp_tag_msg_recv_nb(worker, buffer, count, datatype, message, cb)
    ccall((:ucp_tag_msg_recv_nb, libucp), ucs_status_ptr_t, (ucp_worker_h, Ptr{Cvoid}, Csize_t, ucp_datatype_t, ucp_tag_message_h, ucp_tag_recv_callback_t), worker, buffer, count, datatype, message, cb)
end

function ucp_tag_msg_recv_nbx(worker, buffer, count, message, param)
    ccall((:ucp_tag_msg_recv_nbx, libucp), ucs_status_ptr_t, (ucp_worker_h, Ptr{Cvoid}, Csize_t, ucp_tag_message_h, Ptr{ucp_request_param_t}), worker, buffer, count, message, param)
end

function ucp_put_nbi(ep, buffer, length, remote_addr, rkey)
    ccall((:ucp_put_nbi, libucp), ucs_status_t, (ucp_ep_h, Ptr{Cvoid}, Csize_t, UInt64, ucp_rkey_h), ep, buffer, length, remote_addr, rkey)
end

function ucp_put_nb(ep, buffer, length, remote_addr, rkey, cb)
    ccall((:ucp_put_nb, libucp), ucs_status_ptr_t, (ucp_ep_h, Ptr{Cvoid}, Csize_t, UInt64, ucp_rkey_h, ucp_send_callback_t), ep, buffer, length, remote_addr, rkey, cb)
end

function ucp_put_nbx(ep, buffer, count, remote_addr, rkey, param)
    ccall((:ucp_put_nbx, libucp), ucs_status_ptr_t, (ucp_ep_h, Ptr{Cvoid}, Csize_t, UInt64, ucp_rkey_h, Ptr{ucp_request_param_t}), ep, buffer, count, remote_addr, rkey, param)
end

function ucp_get_nbi(ep, buffer, length, remote_addr, rkey)
    ccall((:ucp_get_nbi, libucp), ucs_status_t, (ucp_ep_h, Ptr{Cvoid}, Csize_t, UInt64, ucp_rkey_h), ep, buffer, length, remote_addr, rkey)
end

function ucp_get_nb(ep, buffer, length, remote_addr, rkey, cb)
    ccall((:ucp_get_nb, libucp), ucs_status_ptr_t, (ucp_ep_h, Ptr{Cvoid}, Csize_t, UInt64, ucp_rkey_h, ucp_send_callback_t), ep, buffer, length, remote_addr, rkey, cb)
end

function ucp_get_nbx(ep, buffer, count, remote_addr, rkey, param)
    ccall((:ucp_get_nbx, libucp), ucs_status_ptr_t, (ucp_ep_h, Ptr{Cvoid}, Csize_t, UInt64, ucp_rkey_h, Ptr{ucp_request_param_t}), ep, buffer, count, remote_addr, rkey, param)
end

function ucp_atomic_post(ep, opcode, value, op_size, remote_addr, rkey)
    ccall((:ucp_atomic_post, libucp), ucs_status_t, (ucp_ep_h, ucp_atomic_post_op_t, UInt64, Csize_t, UInt64, ucp_rkey_h), ep, opcode, value, op_size, remote_addr, rkey)
end

function ucp_atomic_fetch_nb(ep, opcode, value, result, op_size, remote_addr, rkey, cb)
    ccall((:ucp_atomic_fetch_nb, libucp), ucs_status_ptr_t, (ucp_ep_h, ucp_atomic_fetch_op_t, UInt64, Ptr{Cvoid}, Csize_t, UInt64, ucp_rkey_h, ucp_send_callback_t), ep, opcode, value, result, op_size, remote_addr, rkey, cb)
end

function ucp_atomic_op_nbx(ep, opcode, buffer, count, remote_addr, rkey, param)
    ccall((:ucp_atomic_op_nbx, libucp), ucs_status_ptr_t, (ucp_ep_h, ucp_atomic_op_t, Ptr{Cvoid}, Csize_t, UInt64, ucp_rkey_h, Ptr{ucp_request_param_t}), ep, opcode, buffer, count, remote_addr, rkey, param)
end

function ucp_request_check_status(request)
    ccall((:ucp_request_check_status, libucp), ucs_status_t, (Ptr{Cvoid},), request)
end

function ucp_tag_recv_request_test(request, info)
    ccall((:ucp_tag_recv_request_test, libucp), ucs_status_t, (Ptr{Cvoid}, Ptr{ucp_tag_recv_info_t}), request, info)
end

function ucp_stream_recv_request_test(request, length_p)
    ccall((:ucp_stream_recv_request_test, libucp), ucs_status_t, (Ptr{Cvoid}, Ptr{Csize_t}), request, length_p)
end

function ucp_request_cancel(worker, request)
    ccall((:ucp_request_cancel, libucp), Cvoid, (ucp_worker_h, Ptr{Cvoid}), worker, request)
end

function ucp_stream_data_release(ep, data)
    ccall((:ucp_stream_data_release, libucp), Cvoid, (ucp_ep_h, Ptr{Cvoid}), ep, data)
end

function ucp_request_free(request)
    ccall((:ucp_request_free, libucp), Cvoid, (Ptr{Cvoid},), request)
end

function ucp_request_alloc(worker)
    ccall((:ucp_request_alloc, libucp), Ptr{Cvoid}, (ucp_worker_h,), worker)
end

function ucp_dt_create_generic(ops, context, datatype_p)
    ccall((:ucp_dt_create_generic, libucp), ucs_status_t, (Ptr{ucp_generic_dt_ops_t}, Ptr{Cvoid}, Ptr{ucp_datatype_t}), ops, context, datatype_p)
end

function ucp_dt_destroy(datatype)
    ccall((:ucp_dt_destroy, libucp), Cvoid, (ucp_datatype_t,), datatype)
end

function ucp_worker_fence(worker)
    ccall((:ucp_worker_fence, libucp), ucs_status_t, (ucp_worker_h,), worker)
end

function ucp_worker_flush_nb(worker, flags, cb)
    ccall((:ucp_worker_flush_nb, libucp), ucs_status_ptr_t, (ucp_worker_h, Cuint, ucp_send_callback_t), worker, flags, cb)
end

function ucp_worker_flush_nbx(worker, param)
    ccall((:ucp_worker_flush_nbx, libucp), ucs_status_ptr_t, (ucp_worker_h, Ptr{ucp_request_param_t}), worker, param)
end

@cenum ucp_ep_attr_field::UInt32 begin
    UCP_EP_ATTR_FIELD_NAME = 1
end

struct ucp_ep_attr
    field_mask::UInt64
    name::NTuple{32, Cchar}
end

const ucp_ep_attr_t = ucp_ep_attr

function ucp_ep_query(ep, attr)
    ccall((:ucp_ep_query, libucp), ucs_status_t, (ucp_ep_h, Ptr{ucp_ep_attr_t}), ep, attr)
end

const UCS_ALLOCA_MAX_SIZE = 1200

# const UCS_EMPTY_STATEMENT = {}

const UCS_MEMORY_TYPES_CPU_ACCESSIBLE = (UCS_BIT(UCS_MEMORY_TYPE_HOST) | UCS_BIT(UCS_MEMORY_TYPE_CUDA_MANAGED)) | UCS_BIT(UCS_MEMORY_TYPE_ROCM_MANAGED)

const UCP_ENTITY_NAME_MAX = 32

const UCP_VERSION_MAJOR_SHIFT = 24

const UCP_VERSION_MINOR_SHIFT = 16

const UCP_API_MAJOR = 1

const UCP_API_MINOR = 11

const UCP_API_VERSION = UCP_VERSION(1, 11)

const UCS_CPU_SETSIZE = 1024

end # module
