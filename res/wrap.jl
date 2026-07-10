using Clang.Generators
using UCX_jll
using MacroTools: @capture, postwalk, prettify
using JuliaFormatter: format_file

include_dir = joinpath(UCX_jll.artifact_dir ,"include")
headers = [joinpath(include_dir, "ucp", "api", header) for header in ["ucp.h"]]

@add_def socklen_t
@add_def sa_family_t
# @add_def sockaddr
@add_def sockaddr_storage
@add_def FILE

# Functions that return `ucs_status_t` are wrapped so that they throw a
# `UCXException` (see epilogue.jl) on a non-`UCS_OK` status.
function rewrite_status_check(expr)
    if !(expr isa Expr) || !@capture(expr, function fname_(fargs__) fbody__ end)
        return expr
    end

    # Find the return type of the @ccall in the body
    rettype = nothing
    postwalk(expr) do x
        if @capture(x, @ccall(inner_)) && @capture(inner, _::rt_)
            rettype = rt
        end
        x
    end
    if rettype !== :ucs_status_t
        return expr
    end

    newfunc = :(@checked $expr)

    return prettify(newfunc)
end

function rewrite!(ctx)
    for node in ctx.dag.nodes
        for i in eachindex(node.exprs)
            node.exprs[i] = rewrite_status_check(node.exprs[i])
        end
    end
end

cd(@__DIR__) do
    args = get_default_args("x86_64-linux-gnu")
    push!(args, "-I$include_dir")

    options = load_options(joinpath(@__DIR__, "wrap.toml"))

    ctx = create_context(headers, args, options)

    build!(ctx, BUILDSTAGE_NO_PRINTING)
    rewrite!(ctx)
    build!(ctx, BUILDSTAGE_PRINTING_ONLY)

    format_file("../src/api.jl"; margin=120)
end
