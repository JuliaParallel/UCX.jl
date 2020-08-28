using UCX
using Sockets

function start_server()
    ctx = UCX.UCXContext()
    worker = UCX.UCXWorker(ctx)
    listener = UCX.UCXListener(worker, 8888)
    # So we also get an endpoint for each client that is connecting, but taged messages bypass that
    while true
        msg = UCX.probe(worker, 777)
        if msg !== nothing
            buf = Array{UInt8}(undef, msg.info.length)
            UCX.recv(worker, msg, buf, length(buf))
            @show String(buf)
            exit(0)
        end
        UCX.progress(worker)
    end
end

function start_client()
    ctx = UCX.UCXContext()
    worker = UCX.UCXWorker(ctx)
    ep = UCX.UCXEndpoint(worker, IPv4("127.0.0.1"), 8888)
    data = "Hello World"
    UCX.send(ep, data, sizeof(data), 777)
    exit(0)
end

