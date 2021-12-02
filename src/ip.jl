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

    struct sockaddr_storage
        data::NTuple{128, UInt8} # _SS_SIZE
    end
end
