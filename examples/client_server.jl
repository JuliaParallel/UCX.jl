using UCX
using Sockets

using UCX: recv, send

using Base.Threads

const default_port = 8890
const expected_clients = Atomic{Int}(0)

function echo_server(ep::UCX.Endpoint)
    size = Int[0]
    wait(recv(ep, size, sizeof(Int)))
    data = Array{UInt8}(undef, size[1])
    wait(recv(ep, data, sizeof(data)))
    wait(send(ep, data, sizeof(data)))
    atomic_sub!(expected_clients, 1)
end

function start_server(ch_port = Channel{Int}(1), port = default_port)
    ctx = UCX.UCXContext()
    worker = UCX.UCXWorker(ctx)

    function listener_callback(conn_request_h::UCX.API.ucp_conn_request_h, args::Ptr{Cvoid})
        conn_request = UCX.UCXConnectionRequest(conn_request_h)
        Threads.@spawn begin
            try
                echo_server(UCX.Endpoint($worker, $conn_request))
            catch err
                showerror(stderr, err, catch_backtrace())
                exit(-1) # Fatal
            end
        end
        nothing
    end
    cb = @cfunction($listener_callback, Cvoid, (UCX.API.ucp_conn_request_h, Ptr{Cvoid}))
    listener = UCX.UCXListener(worker, port, cb)
    push!(ch_port, listener.port)

    GC.@preserve listener cb begin
        while expected_clients[] > 0
            UCX.progress(worker)
            yield()
        end
    end
end

function start_client(port=default_port)
    ctx = UCX.UCXContext()
    worker = UCX.UCXWorker(ctx)
    ep = UCX.Endpoint(worker, IPv4("127.0.0.1"), port)

    data = "Hello world"
    req1 = send(ep, Int[sizeof(data)], sizeof(Int)) # XXX: Order gurantuees?
    req2 = send(ep, data, sizeof(data))
    wait(req1); wait(req2)
    buffer = Array{UInt8}(undef, sizeof(data))
    wait(recv(ep, buffer, sizeof(buffer)))
    @assert String(buffer) == data
end

if !isinteractive()
    @assert length(ARGS) >= 1 "Expected command line argument role: 'client', 'server', 'test'"
    kind = ARGS[1]
    expected_clients[] = length(ARGS) == 2 ? parse(Int, ARGS[2]) : 1
    if kind == "server"
        start_server()
    elseif kind == "client"
        start_client()
    elseif kind =="test"
        ch_port = Channel{Int}(1)
        @sync begin
            UCX.@spawn_showerr start_server(ch_port, nothing)
            port = take!(ch_port)
            for i in 1:expected_clients[]
                UCX.@spawn_showerr start_client(port)
            end
        end
    end
end
