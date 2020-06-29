module API
    using UCX_jll
    using CEnum
    include("ctypes.jl")

    # For now we only wrap UCP
    include(joinpath(@__DIR__, "..", "gen", "libucs_common_minimal.jl"))
    include(joinpath(@__DIR__, "..", "gen", "libucp_common.jl"))
    include(joinpath(@__DIR__, "..", "gen", "libucp_api.jl"))
end
