# Automatically generated using Clang.jl wrap_c


# Skipping MacroDefinition: ucp_dt_make_contig ( _elem_size ) ( ( ( ucp_datatype_t ) ( _elem_size ) << UCP_DATATYPE_SHIFT ) | UCP_DATATYPE_CONTIG )
# Skipping MacroDefinition: ucp_dt_make_iov ( ) ( UCP_DATATYPE_IOV )

@cenum(ucp_params_field,
    UCP_PARAM_FIELD_FEATURES = 1,
    UCP_PARAM_FIELD_REQUEST_SIZE = 2,
    UCP_PARAM_FIELD_REQUEST_INIT = 4,
    UCP_PARAM_FIELD_REQUEST_CLEANUP = 8,
    UCP_PARAM_FIELD_TAG_SENDER_MASK = 16,
    UCP_PARAM_FIELD_MT_WORKERS_SHARED = 32,
    UCP_PARAM_FIELD_ESTIMATED_NUM_EPS = 64,
)
@cenum(ucp_feature,
    UCP_FEATURE_TAG = 1,
    UCP_FEATURE_RMA = 2,
    UCP_FEATURE_AMO32 = 4,
    UCP_FEATURE_AMO64 = 8,
    UCP_FEATURE_WAKEUP = 16,
    UCP_FEATURE_STREAM = 32,
    UCP_FEATURE_EXPERIMENTAL = 64,
)
@cenum(ucp_worker_params_field,
    UCP_WORKER_PARAM_FIELD_THREAD_MODE = 1,
    UCP_WORKER_PARAM_FIELD_CPU_MASK = 2,
    UCP_WORKER_PARAM_FIELD_EVENTS = 4,
    UCP_WORKER_PARAM_FIELD_USER_DATA = 8,
    UCP_WORKER_PARAM_FIELD_EVENT_FD = 16,
)
@cenum(ucp_listener_params_field,
    UCP_LISTENER_PARAM_FIELD_SOCK_ADDR = 1,
    UCP_LISTENER_PARAM_FIELD_ACCEPT_HANDLER = 2,
    UCP_LISTENER_PARAM_FIELD_CONN_HANDLER = 4,
)
@cenum(ucp_worker_address_flags_t,
    UCP_WORKER_ADDRESS_FLAG_NET_ONLY = 1,
)
@cenum(ucp_ep_params_field,
    UCP_EP_PARAM_FIELD_REMOTE_ADDRESS = 1,
    UCP_EP_PARAM_FIELD_ERR_HANDLING_MODE = 2,
    UCP_EP_PARAM_FIELD_ERR_HANDLER = 4,
    UCP_EP_PARAM_FIELD_USER_DATA = 8,
    UCP_EP_PARAM_FIELD_SOCK_ADDR = 16,
    UCP_EP_PARAM_FIELD_FLAGS = 32,
    UCP_EP_PARAM_FIELD_CONN_REQUEST = 64,
)
@cenum(ucp_ep_params_flags_field,
    UCP_EP_PARAMS_FLAGS_CLIENT_SERVER = 1,
    UCP_EP_PARAMS_FLAGS_NO_LOOPBACK = 2,
)
@cenum(ucp_ep_close_mode,
    UCP_EP_CLOSE_MODE_FORCE = 0,
    UCP_EP_CLOSE_MODE_FLUSH = 1,
)
@cenum(ucp_mem_map_params_field,
    UCP_MEM_MAP_PARAM_FIELD_ADDRESS = 1,
    UCP_MEM_MAP_PARAM_FIELD_LENGTH = 2,
    UCP_MEM_MAP_PARAM_FIELD_FLAGS = 4,
)
@cenum(ucp_mem_advise_params_field,
    UCP_MEM_ADVISE_PARAM_FIELD_ADDRESS = 1,
    UCP_MEM_ADVISE_PARAM_FIELD_LENGTH = 2,
    UCP_MEM_ADVISE_PARAM_FIELD_ADVICE = 4,
)
@cenum(ucp_context_attr_field,
    UCP_ATTR_FIELD_REQUEST_SIZE = 1,
    UCP_ATTR_FIELD_THREAD_MODE = 2,
)
@cenum(ucp_worker_attr_field,
    UCP_WORKER_ATTR_FIELD_THREAD_MODE = 1,
    UCP_WORKER_ATTR_FIELD_ADDRESS = 2,
    UCP_WORKER_ATTR_FIELD_ADDRESS_FLAGS = 4,
)
@cenum(ucp_dt_type,
    UCP_DATATYPE_CONTIG = 0,
    UCP_DATATYPE_STRIDED = 1,
    UCP_DATATYPE_IOV = 2,
    UCP_DATATYPE_GENERIC = 7,
    UCP_DATATYPE_SHIFT = 3,
    UCP_DATATYPE_CLASS_MASK = 7,
)
@cenum(ucp_atomic_post_op_t,
    UCP_ATOMIC_POST_OP_ADD = 0,
    UCP_ATOMIC_POST_OP_AND = 1,
    UCP_ATOMIC_POST_OP_OR = 2,
    UCP_ATOMIC_POST_OP_XOR = 3,
    UCP_ATOMIC_POST_OP_LAST = 4,
)
@cenum(ucp_atomic_fetch_op_t,
    UCP_ATOMIC_FETCH_OP_FADD = 0,
    UCP_ATOMIC_FETCH_OP_SWAP = 1,
    UCP_ATOMIC_FETCH_OP_CSWAP = 2,
    UCP_ATOMIC_FETCH_OP_FAND = 3,
    UCP_ATOMIC_FETCH_OP_FOR = 4,
    UCP_ATOMIC_FETCH_OP_FXOR = 5,
    UCP_ATOMIC_FETCH_OP_LAST = 6,
)
@cenum(ucp_stream_recv_flags_t,
    UCP_STREAM_RECV_FLAG_WAITALL = 1,
)

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
const ucp_request_init_callback_t = Ptr{Cvoid}
const ucp_request_cleanup_callback_t = Ptr{Cvoid}

struct ucp_params
    field_mask::UInt64
    features::UInt64
    request_size::Csize_t
    request_init::ucp_request_init_callback_t
    request_cleanup::ucp_request_cleanup_callback_t
    tag_sender_mask::UInt64
    mt_workers_shared::Cint
    estimated_num_eps::Csize_t
end

const ucp_params_t = ucp_params

struct ucp_context_attr
    field_mask::UInt64
    request_size::Csize_t
    thread_mode::ucs_thread_mode_t
end

const ucp_context_attr_t = ucp_context_attr
const ucp_address = Cvoid
const ucp_address_t = ucp_address

struct ucp_worker_attr
    field_mask::UInt64
    thread_mode::ucs_thread_mode_t
    address_flags::UInt32
    address::Ptr{ucp_address_t}
    address_length::Csize_t
end

const ucp_worker_attr_t = ucp_worker_attr

struct ucp_worker_params
    field_mask::UInt64
    thread_mode::ucs_thread_mode_t
    cpu_mask::ucs_cpu_set_t
    events::UInt32
    user_data::Ptr{Cvoid}
    event_fd::Cint
end

const ucp_worker_params_t = ucp_worker_params
const ucp_listener_accept_callback_t = Ptr{Cvoid}

struct ucp_listener_accept_handler
    cb::ucp_listener_accept_callback_t
    arg::Ptr{Cvoid}
end

const ucp_listener_accept_handler_t = ucp_listener_accept_handler
const ucp_listener_conn_callback_t = Ptr{Cvoid}

struct ucp_listener_conn_handler
    cb::ucp_listener_conn_callback_t
    arg::Ptr{Cvoid}
end

const ucp_listener_conn_handler_t = ucp_listener_conn_handler

struct ucp_listener_params
    field_mask::UInt64
    sockaddr::ucs_sock_addr_t
    accept_handler::ucp_listener_accept_handler_t
    conn_handler::ucp_listener_conn_handler_t
end

const ucp_listener_params_t = ucp_listener_params
const ucp_ep = Cvoid
const ucp_ep_h = Ptr{ucp_ep}

struct ucp_stream_poll_ep_t
    ep::ucp_ep_h
    user_data::Ptr{Cvoid}
    flags::UInt32
    reserved::NTuple{16, UInt8}
end

struct ucp_mem_map_params
    field_mask::UInt64
    address::Ptr{Cvoid}
    length::Csize_t
    flags::UInt32
end

const ucp_mem_map_params_t = ucp_mem_map_params
const ucp_tag_t = UInt64

struct ucp_tag_recv_info
    sender_tag::ucp_tag_t
    length::Csize_t
end

@cenum(ucp_mem_advice,
    UCP_MADV_NORMAL = 0,
    UCP_MADV_WILLNEED = 1,
)

const ucp_mem_advice_t = ucp_mem_advice

struct ucp_mem_advise_params
    field_mask::UInt64
    address::Ptr{Cvoid}
    length::Csize_t
    advice::ucp_mem_advice_t
end

const ucp_mem_advise_params_t = ucp_mem_advise_params
const ucp_tag_recv_info_t = ucp_tag_recv_info
const ucp_context = Cvoid
const ucp_context_h = Ptr{ucp_context}
const ucp_config = Cvoid
const ucp_config_t = ucp_config
const ucp_conn_request = Cvoid
const ucp_conn_request_h = Ptr{ucp_conn_request}

@cenum(ucp_err_handling_mode_t,
    UCP_ERR_HANDLING_MODE_NONE = 0,
    UCP_ERR_HANDLING_MODE_PEER = 1,
)

const ucp_rkey = Cvoid
const ucp_rkey_h = Ptr{ucp_rkey}
const ucp_mem = Cvoid
const ucp_mem_h = Ptr{ucp_mem}
const ucp_listener = Cvoid
const ucp_listener_h = Ptr{ucp_listener}

struct ucp_mem_attr
    field_mask::UInt64
    address::Ptr{Cvoid}
    length::Csize_t
end

const ucp_mem_attr_t = ucp_mem_attr

@cenum(ucp_mem_attr_field,
    UCP_MEM_ATTR_FIELD_ADDRESS = 1,
    UCP_MEM_ATTR_FIELD_LENGTH = 2,
)

const ucp_worker = Cvoid
const ucp_worker_h = Ptr{ucp_worker}
const ucp_recv_desc = Cvoid
const ucp_tag_message_h = Ptr{ucp_recv_desc}
const ucp_datatype_t = UInt64
const ucp_send_callback_t = Ptr{Cvoid}
const ucp_err_handler_cb_t = Ptr{Cvoid}

struct ucp_err_handler
    cb::ucp_err_handler_cb_t
    arg::Ptr{Cvoid}
end

const ucp_err_handler_t = ucp_err_handler
const ucp_stream_recv_callback_t = Ptr{Cvoid}
const ucp_tag_recv_callback_t = Ptr{Cvoid}

@cenum(ucp_wakeup_event_types,
    UCP_WAKEUP_RMA = 1,
    UCP_WAKEUP_AMO = 2,
    UCP_WAKEUP_TAG_SEND = 4,
    UCP_WAKEUP_TAG_RECV = 8,
    UCP_WAKEUP_TX = 1024,
    UCP_WAKEUP_RX = 2048,
    UCP_WAKEUP_EDGE = 65536,
)

const ucp_wakeup_event_t = ucp_wakeup_event_types

struct ucp_ep_params
    field_mask::UInt64
    address::Ptr{ucp_address_t}
    err_mode::ucp_err_handling_mode_t
    err_handler::ucp_err_handler_t
    user_data::Ptr{Cvoid}
    flags::UInt32
    sockaddr::ucs_sock_addr_t
    conn_request::ucp_conn_request_h
end

const ucp_ep_params_t = ucp_ep_params

# Skipping MacroDefinition: UCP_VERSION ( _major , _minor ) ( ( ( _major ) << UCP_VERSION_MAJOR_SHIFT ) | ( ( _minor ) << UCP_VERSION_MINOR_SHIFT ) )

const UCP_VERSION_MAJOR_SHIFT = 24
const UCP_VERSION_MINOR_SHIFT = 16
const UCP_API_MAJOR = 1
const UCP_API_MINOR = 6

# Skipping MacroDefinition: UCP_API_VERSION UCP_VERSION ( 1 , 6 )
