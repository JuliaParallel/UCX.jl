# VSCode

```julia
f() = for i in 1:1000
    UCX.Legacy.remotecall_wait(()->true, 2)
end

g() = for i in 1:1000
    remotecall_wait(()->true, 2)
end

@profview f()
@profview g()
```

# Microbenchmarks

```julia
using BenchmarkTools


@benchmark UCX.Legacy.remotecall(()->true, 2) #  2.502 μs
@benchmark remotecall(()->true, 2) # 11.502 μs

data = Array{UInt8}(undef, 8192)
@benchmark UCX.Legacy.remotecall((x)->true, 2, $data) # 2.767 μs
@benchmark remotecall((x)->true, 2, $data) # 17.380 μs

@benchmark UCX.Legacy.remote_do(()->true, 2) # 1.802 μs


@benchmark UCX.Legacy.remotecall(()->true, 2) #  2.502 μs
@benchmark remotecall(()->true, 2) # 11.502 μs

data = Array{UInt8}(undef, 8192)
@benchmark UCX.Legacy.remotecall((x)->true, 2, $data) # 2.767 μs
@benchmark remotecall((x)->true, 2, $data) # 17.380 μs

@benchmark UCX.Legacy.remote_do(()->true, 2) # 1.802 μs
@benchmark remote_do(()->true, 2) # 10.190 μs

@benchmark UCX.Legacy.remotecall_wait(()->true, 2) # 1ms (Timer) 20.320 μs (busy) 42μs (poll_fd)
@benchmark remotecall_wait(()->true, 2) # 40 μs

@benchmark UCX.Legacy.remotecall_fetch(()->true, 2) # 1ms (Timer) 14.560 μs (busy) 31μs (poll_fd)
@benchmark remotecall_fetch(()->true, 2) # 40 μs

# Base line
@benchmark(wait(@async(nothing))) # 1 μs
```

# PProf

```julia
@everywhere using Profile, PProf

Profile.clear()
remotecall_wait(Profile.clear, 2)
remotecall_wait(Profile.start_timer, 2)
Profile.start_timer()
@benchmark UCX.Legacy.remotecall_wait(()->true, 2) 
Profile.stop_timer()
remotecall_wait(Profile.stop_timer, 2)
remotecall_wait(PProf.pprof, 2, web=false, out="proc2.pb.gz")
PProf.pprof(web=false, out="proc1.pb.gz")
```