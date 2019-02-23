using Clang

# LIBUCP_HEADERS are those headers to be wrapped.
const LIBUCP_INCLUDE = joinpath(@__DIR__, "..", "deps", "usr", "include", "ucp", "api") |> normpath
const LIBUCP_HEADERS = [joinpath(LIBUCP_INCLUDE, header) for header in readdir(LIBUCP_INCLUDE) if endswith(header, ".h")]

wc = init(; headers = LIBUCP_HEADERS,
            output_file = joinpath(@__DIR__, "libucp_api.jl"),
            common_file = joinpath(@__DIR__, "libucp_common.jl"),
            clang_includes = vcat(LIBUCP_INCLUDE, CLANG_INCLUDE),
            clang_args = ["-I", joinpath(LIBUCP_INCLUDE, "..", "..")],
            header_wrapped = (root, current)->root == current,
            header_library = x->"libucp",
            clang_diagnostics = true,
            )

run(wc)
