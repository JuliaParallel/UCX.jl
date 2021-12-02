
include(joinpath(@__DIR__, "..", "deps", "deps.jl"))

const FILE = Base.Libc.FILE
const __socklen_t = Cuint
const socklen_t = __socklen_t
const sa_family_t = Cushort

# FIXME: Clang.jl should have defined this
UCS_BIT(i) = (UInt(1) << (convert(UInt, i)))
UCP_VERSION(_major, _minor) = (((_major) << UCP_VERSION_MAJOR_SHIFT) | ((_minor) << UCP_VERSION_MINOR_SHIFT))
