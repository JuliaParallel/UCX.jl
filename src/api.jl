module API
    using UCX_jll
    using CEnum
    include(joinpath("api", "ctypes.jl"))

    # For now we only wrap UCP
    include(joinpath("api", "libucs_common_minimal.jl"))
    include(joinpath("api", "libucp_common.jl"))
    include(joinpath("api", "libucp_api.jl"))
end
