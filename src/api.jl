module API
    const ext = joinpath(@__DIR__, "..", "deps", "ext.jl")
    isfile(ext) || error("UCX.jl has not been built, please run Pkg.build(\"UCX\").")
    include(ext)

    using CEnum
    include("ctypes.jl")

    # For now we only wrap UCP
    include(joinpath(@__DIR__, "..", "gen", "libucs_common_minimal.jl"))
    include(joinpath(@__DIR__, "..", "gen", "libucp_common.jl"))
    include(joinpath(@__DIR__, "..", "gen", "libucp_api.jl"))
end
