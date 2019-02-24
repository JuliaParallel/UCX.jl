## TODO: pending https://github.com/JuliaLang/julia/issues/29420
# this one is suggested in the issue, but it looks like time_t and tm are two different things?
# const Ctime_t = Base.Libc.TmStruct

const Ctm = Base.Libc.TmStruct
const Ctime_t = UInt
const Cclock_t = UInt
const SIZE_MAX = typemax(Csize_t)
const sockaddr = Ptr{Cvoid}
const socklen_t = Cuint
const intptr_t = Int
const ssize_t = Cssize_t
const FILE = Cint

@static if ccall(:jl_sizeof_off_t, Cint,()) == 4
    const off_t = Int32
else
    const off_t = Int64
end

