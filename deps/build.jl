using Libdl

if haskey(ENV, "JULIA_SYSTEM_UCX")
    @info "using system UCX"

    paths = String[]
    if haskey(ENV, "JULIA_UCX_LIBPATH")
        push!(paths,)
        libucp = ENV["JULIA_UCP_LIB"]
    else
        libucp = Libdl.find_library(["libucp"], [])
        libucs = Libdl.find_library(["libucs"], [])
        @debug "UCX paths" libucp libucs
        if isempty(libucs) || isempty(libucp)
            error("Did not find UCX libraries, please set the JULIA_UCX_LIBPATH environment variable.")
        end
    end

    deps = quote
        const libucp = $libucp
        const libucs = $libucs
    end
else
    deps = quote
        import UCX_jll: libucp, libucs
    end
end

remove_line_numbers(x) = x
function remove_line_numbers(ex::Expr)
    if ex.head == :macrocall
        ex.args[2] = nothing
    else
        ex.args = [remove_line_numbers(arg) for arg in ex.args if !(arg isa LineNumberNode)]
    end
    return ex
end

# only update deps.jl if it has changed.
# allows users to call Pkg.build("FluxRM") without triggering another round of precompilation
deps_str = string(remove_line_numbers(deps))

if !isfile("deps.jl") || deps_str != read("deps.jl", String)
    write("deps.jl", deps_str)
end