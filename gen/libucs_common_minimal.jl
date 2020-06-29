@cenum ucs_thread_mode_t begin
    UCS_THREAD_MODE_SINGLE = 0
    UCS_THREAD_MODE_SERIALIZED = 1
    UCS_THREAD_MODE_MULTI = 2
    UCS_THREAD_MODE_LAST = 3
end

const ucs_cpu_mask_t = Culong

struct ucs_cpu_set_t
    ucs_bits::NTuple{16, ucs_cpu_mask_t}
end

struct ucs_sock_addr
    addr::Ptr{sockaddr}
    addrlen::socklen_t
end

const ucs_sock_addr_t = ucs_sock_addr

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
    UCS_ERR_FIRST_LINK_FAILURE = -40
    UCS_ERR_LAST_LINK_FAILURE = -59
    UCS_ERR_FIRST_ENDPOINT_FAILURE = -60
    UCS_ERR_LAST_ENDPOINT_FAILURE = -79
    UCS_ERR_ENDPOINT_TIMEOUT = -80
    UCS_ERR_LAST = -100
end

@cenum ucs_config_print_flags_t begin
    UCS_CONFIG_PRINT_CONFIG = 1
    UCS_CONFIG_PRINT_HEADER = 2
    UCS_CONFIG_PRINT_DOC = 4
    UCS_CONFIG_PRINT_HIDDEN = 8
end

const ucs_status_ptr_t = Ptr{Cvoid}

