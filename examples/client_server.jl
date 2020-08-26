using UCX
using Sockets

function start_server()
    ctx = UCX.UCXContext()
    worker = UCX.UCXWorker(ctx)
    listener = UCX.UCXListener(worker, 8888)
    while true
        UCX.progress(worker)
    end
end

function start_client()
    ctx = UCX.UCXContext()
    worker = UCX.UCXWorker(ctx)
    ep = UCX.UCXEndpoint(worker, IPv4("127.0.0.1"), 8888)

end
