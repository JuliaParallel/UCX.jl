using Clang
using UCX_jll

UCS = joinpath(UCX_jll.artifact_dir, "include", "ucs") |> normpath
UCS_INCLUDES = [joinpath(UCS, dir) for dir in readdir(UCS)]
UCS_HEADERS = String[]
for dir in UCS_INCLUDES
    headers = [joinpath(dir, header) for header in readdir(dir) if endswith(header, ".h")]
    append!(UCS_HEADERS, headers)
end

wc = init(; headers = UCS_HEADERS,
            output_file = joinpath(@__DIR__, "libucs_api.jl"),
            common_file = joinpath(@__DIR__, "libucs_common.jl"),
            clang_includes = vcat(UCS_INCLUDES, CLANG_INCLUDE),
            clang_args = ["-I", joinpath(UCS, "..")],
            header_wrapped = (root, current)->root == current,
            header_library = x->"libucs",
            clang_diagnostics = true,
            )
run(wc)


function wrap_ucx_component(name)
    INCLUDE = joinpath(UCX_jll.artifact_dir, "include", name, "api") |> normpath
    HEADERS = [joinpath(INCLUDE, header) for header in readdir(INCLUDE) if endswith(header, ".h")]
    
    wc = init(; headers = HEADERS,
                output_file = joinpath(@__DIR__, "lib$(name)_api.jl"),
                common_file = joinpath(@__DIR__, "lib$(name)_common.jl"),
                clang_includes = vcat(INCLUDE, CLANG_INCLUDE),
                clang_args = ["-I", joinpath(INCLUDE, "..", "..")],
                header_wrapped = (root, current)->root == current,
                header_library = x->"lib$name",
                clang_diagnostics = true,
                )
    
    run(wc)
end
wrap_ucx_component("ucm")
wrap_ucx_component("uct")
wrap_ucx_component("ucp")
