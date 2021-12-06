using Test

# Assumes wireup has already happened, see setup.jl

@everywhere using UCX, Test

@everywhere begin

function setup()
    ctx = UCX.context(UCX_WORKER)
    data = Vector{UInt8}(undef, 64)

    mem = UCX.Memory(ctx, data)
    rkey_local = UCX.rkey_pack(mem)
    data, mem, rkey_local
end 

function test_memory()
    data, mem, rkey_local = setup()
    ep_local = proc_to_endpoint(myid())
    rkey = UCX.RemoteKey(ep_local, rkey_local)

    try
        ptr = pointer(rkey, mem.base)
        @test ptr  == Base.unsafe_convert(Ptr{Cvoid}, pointer(mem))
    catch err
        if err isa UCX.UCXException && err == UCX.UCXException(UCX.API.UCS_ERR_UNREACHABLE)
            @test true
        else
            rethrow(err)
        end
    end

    return
end

test_memory()
end

@everywhere begin
    data, mem, rkey_local = setup()
    neighbor = mod1(myid() + 1, nprocs())
    remotecall_wait(neighbor, rkey_local) do rkey
        global rkey_neighbor = rkey
    end
end

@everywhere begin
    ep = proc_to_endpoint(neighbor)
    rkey = UCX.RemoteKey(ep, rkey_neighbor)
end