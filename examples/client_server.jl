using UCX
using Sockets

using UCX: UCXEndpoint
using UCX: recv, send

const port = 8890

function echo_server(ep::UCXEndpoint)
    @info "Starting echo_server"
    size = Int[0]
    recv(ep.worker, size, sizeof(Int), 777)
    @info "recv size" size[1]
    data = Array{UInt8}(undef, size[1])
    recv(ep.worker, data, sizeof(data), 777)
    @info "recv data"
    send(ep, data, sizeof(data), 777)
    @info "Echo!"
end

function start_server()
    ctx = UCX.UCXContext()
    worker = UCX.UCXWorker(ctx)

    function listener_callback(conn_request_h::UCX.API.ucp_conn_request_h, args::Ptr{Cvoid})
        conn_request = UCX.UCXConnectionRequest(conn_request_h)
        Threads.@spawn begin
            @info "hello from thread"
            # TODO: Errors in echo_server are not shown...
            try
                echo_server(UCXEndpoint($worker, $conn_request))
            catch err
                showerror(err, catch_backtrace())
                exit(-1)
            end
        end
        nothing
    end
    cb = @cfunction($listener_callback, Cvoid, (UCX.API.ucp_conn_request_h, Ptr{Cvoid}))
    listener = UCX.UCXListener(worker, port, cb)

    while true
        UCX.progress(worker)
        yield()
    end
end

function start_client()
    ctx = UCX.UCXContext()
    worker = UCX.UCXWorker(ctx)
    ep = UCX.UCXEndpoint(worker, IPv4("127.0.0.1"), port)

    data = "Hello world"
    @info "sending size" sizeof(data)
    UCX.send(ep, Int[sizeof(data)], sizeof(Int), 777)
    @info "sending data"
    UCX.send(ep, data, sizeof(data), 777)
    @info "recv data"
    buffer = Array{UInt8}(undef, sizeof(data))
    UCX.recv(worker, buffer, sizeof(buffer), 777)
    @assert String(buffer) == data
    exit(0)
end

