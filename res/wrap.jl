using Clang.Generators
using UCX_jll

include_dir = joinpath(UCX_jll.artifact_dir ,"include")

options = load_options(joinpath(@__DIR__, "wrap.toml"))

args = get_default_args()
push!(args, "-I$include_dir")

headers = [joinpath(include_dir, "ucp", "api", header) for header in ["ucp.h"]]

@add_def socklen_t
@add_def sa_family_t
# @add_def sockaddr
@add_def sockaddr_storage
@add_def FILE

ctx = create_context(headers, args, options)
build!(ctx)