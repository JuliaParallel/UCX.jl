using UCX
using Sockets

using UCX: UCXEndpoint
using UCX: recv, send, stream_recv, stream_send

using Base.Threads

const port = 8890
const expected_clients = Atomic{Int}(0)

function echo_server(ep::UCXEndpoint)
    size = Int[0]
    recv(ep.worker, size, sizeof(Int), 777)
    data = Array{UInt8}(undef, size[1])
    stream_recv(ep, data, sizeof(data))
    stream_send(ep, data, sizeof(data))
    atomic_sub!(expected_clients, 1)
end

function start_server(ready=Event())
    ctx = UCX.UCXContext()
    worker = UCX.UCXWorker(ctx)

    function listener_callback(conn_request_h::UCX.API.ucp_conn_request_h, args::Ptr{Cvoid})
        conn_request = UCX.UCXConnectionRequest(conn_request_h)
        Threads.@spawn begin
            # TODO: Errors in echo_server are not shown...
            try
                echo_server(UCXEndpoint($worker, $conn_request))
            catch err
                showerror(stderr, err, catch_backtrace())
                exit(-1)
            end
        end
        nothing
    end
    cb = @cfunction($listener_callback, Cvoid, (UCX.API.ucp_conn_request_h, Ptr{Cvoid}))
    listener = UCX.UCXListener(worker, port, cb)
    notify(ready)
    while expected_clients[] > 0
        UCX.progress(worker)
        yield()
    end
    exit(0)
end

function start_client()
    ctx = UCX.UCXContext()
    worker = UCX.UCXWorker(ctx)
    ep = UCX.UCXEndpoint(worker, IPv4("127.0.0.1"), port)

    data = "Hello world"
    send(ep, Int[sizeof(data)], sizeof(Int), 777)
    stream_send(ep, data, sizeof(data))
    buffer = Array{UInt8}(undef, sizeof(data))
    stream_recv(ep, buffer, sizeof(buffer))
    @assert String(buffer) == data
    exit(0)
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
        event = Event()
        @sync begin
            @async start_server(event)
            wait(event)
            for i in 1:expected_clients[]
                @async start_client()
            end
        end
    end
end
