
using ..UCX: libucp

const FILE = Base.Libc.FILE
const __socklen_t = Cuint
const socklen_t = __socklen_t
const sa_family_t = Cushort

# FIXME: Clang.jl should have defined this
UCS_BIT(i) = (UInt(1) << (convert(UInt, i)))
UCP_VERSION(_major, _minor) = (((_major) << UCP_VERSION_MAJOR_SHIFT) | ((_minor) << UCP_VERSION_MINOR_SHIFT))


macro check(ex)
    quote
        status = $(esc(ex))
        if status !== UCS_OK
            throw(UCXException(status))
        end
    end
end

# Gleefully stolen from GPUToolbox.jl:
# https://github.com/JuliaGPU/GPUToolbox.jl/blob/f971bcdeb2cd8096333549e6563cf03a76459ae2/src/ccalls.jl#L19
#
# Macro for wrapping a function definition returning a status code. Two versions
# of the function will be generated: `foo`, which does a safety check on the
# status code, and `unchecked_foo` where the status code is directly returned to
# the caller.
macro checked(ex)
    # parse the function definition
    @assert Meta.isexpr(ex, :function)
    sig = ex.args[1]
    @assert Meta.isexpr(sig, :call)
    body = ex.args[2]
    @assert Meta.isexpr(body, :block)

    # make sure these functions are inlined
    pushfirst!(body.args, Expr(:meta, :inline))

    # generate a "safe" version that performs a check
    safe_body = quote
        @inline
        ret = $body
        @check ret

        ret
    end
    safe_sig = Expr(:call, sig.args[1], sig.args[2:end]...)
    safe_def = Expr(:function, safe_sig, safe_body)

    # generate a "unchecked" version that returns the error code instead
    unchecked_sig = Expr(:call, Symbol("unchecked_", sig.args[1]), sig.args[2:end]...)
    unchecked_def = Expr(:function, unchecked_sig, body)

    return esc(:($safe_def, $unchecked_def))
end
