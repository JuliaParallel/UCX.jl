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

function bounce(ep, data, remote_addr, rkey)
    preq = put!(ep, data, sizeof(data), remote_addr, rkey)
    wait(flush(ep))

    # data now safe to re-use
    data .= 0
    wait(preq)

    req = get!(ep, data, sizeof(data), remote_addr, rkey)
    wait(req)
    return data
end


function test_memory()
    buffer, mem, rkey_local = setup()
    ep_local = proc_to_endpoint(myid())
    rkey = UCX.RemoteKey(ep_local, rkey_local)

    try
        ptr = pointer(rkey, mem.base)
        @test ptr  == Base.unsafe_convert(Ptr{Cvoid}, pointer(buffer))
    catch err
        if err isa UCX.UCXException && err == UCX.UCXException(UCX.API.UCS_ERR_UNREACHABLE)
            @test true
        else
            rethrow(err)
        end
    end

    wait(flush(UCX_WORKER))

    data = Ref{Int8}(-1)
    preq = put!(ep_local, data, mem.base, rkey)
    wait(flush(ep_local))

    # data now safe to re-use
    data[] = 0
    wait(preq)
    @test buffer[1] == -1 % UInt8

    req = get!(ep_local, data, mem.base, rkey)
    wait(req)
    @test data[] == -1

    data = rand(8)
    check_data = copy(data)
    @test bounce(ep_local, check_data, mem.base, rkey) == check_data

    return
end

test_memory()
end

@everywhere begin
    data, mem, rkey_local = setup()
    neighbor = mod1(myid() + 1, nprocs())
    remotecall_wait(neighbor, rkey_local, mem.base) do rkey, base_addr
        global rkey_neighbor = rkey
        global base_addr_neighbor = base_addr
    end

    nothing
end

@everywhere begin
    ep = proc_to_endpoint(neighbor)
    rkey = UCX.RemoteKey(ep, rkey_neighbor)

    data = Ref{Int8}(-1)
    preq = put!(ep, data, base_addr_neighbor, rkey)
    wait(flush(ep))

    # data now safe to re-use
    data[] = 0
    wait(preq)

    req = get!(ep, data, base_addr_neighbor, rkey)
    wait(req)
    @test data[] == -1

    data = rand(8)
    check_data = copy(data)
    @test bounce(ep, check_data, base_addr_neighbor, rkey) == check_data
    nothing
end