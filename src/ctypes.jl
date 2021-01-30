## TODO: pending https://github.com/JuliaLang/julia/issues/29420
# this one is suggested in the issue, but it looks like time_t and tm are two different things?
# const Ctime_t = Base.Libc.TmStruct

const Ctm = Base.Libc.TmStruct
const Ctime_t = UInt
const Cclock_t = UInt
const SIZE_MAX = typemax(Csize_t)
# const sockaddr = Ptr{Cvoid}
const socklen_t = Cuint
const intptr_t = Int
const ssize_t = Cssize_t
const FILE = Base.Libc.FILE

@static if ccall(:jl_sizeof_off_t, Cint,()) == 4
    const off_t = Int32
else
    const off_t = Int64
end

module IP
    using Sockets: InetAddr, IPv4
    const AF_INET = Cshort(2)

    const INADDR_ANY      = Culong(0x00000000)
    const INADDR_LOOPBACK = Culong(0x7f000001)
    const INADDR_NONE     = Culong(0xffffffff)
    struct in_addr 
        s_addr::Cuint
    end

    struct sockaddr_in
        sin_family::Cshort
        sin_port::Cushort
        sin_addr::in_addr
        sin_zero::NTuple{8, Cchar}

        function sockaddr_in(port, addr)
            new(AF_INET, port, addr, ntuple(_-> Cchar(0), 8))
        end
    end
    function sockaddr_in(addr::InetAddr{IPv4})
        host_in = in_addr(hton(addr.host.host))
        sockaddr_in(hton(convert(Cushort, addr.port)), host_in)
    end
end
const sockaddr = IP.sockaddr_in