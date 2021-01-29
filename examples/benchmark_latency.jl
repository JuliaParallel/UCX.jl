using UCX
using Printf
using Sockets

const port = 8890

const MAX_MESSAGE_SIZE = 1<<22
const LARGE_MESSAGE_SIZE = 8192

const LAT_LOOP_SMALL = 10000
const LAT_SKIP_SMALL = 100
const LAT_LOOP_LARGE = 1000
const LAT_SKIP_LARGE = 10

# Inspired by OSU Microbenchmark latency test

function prettytime(t)
    if t < 1e3
        value, units = t, "ns"
    elseif t < 1e6
        value, units = t / 1e3, "μs"
    elseif t < 1e9
        value, units = t / 1e6, "ms"
    else
        value, units = t / 1e9, "s"
    end
    return string(@sprintf("%.3f", value), " ", units)
end

function touch_data(send_buf, recv_buf, size)
    send_buf[1:size] .= 'A' % UInt8
    recv_buf[1:size] .= 'B' % UInt8
end

function benchmark(ep, myid)
    recv_buf = Vector{UInt8}(undef, MAX_MESSAGE_SIZE)
    send_buf = Vector{UInt8}(undef, MAX_MESSAGE_SIZE)

    @info "Let's go!"
    size = 1
    while size <= MAX_MESSAGE_SIZE
        touch_data(send_buf, recv_buf, size)

        if size > LARGE_MESSAGE_SIZE
            loop = LAT_LOOP_LARGE
            skip = LAT_SKIP_LARGE
        else
            loop = LAT_LOOP_SMALL
            skip = LAT_SKIP_SMALL
        end

        # TODO Barrier

        t_start = 0
        t_end = 0
        if myid == 0
            for i in -skip:loop
                if i == 1
                    t_start = Base.time_ns()
                end

                UCX.stream_send(ep, send_buf, size)
                UCX.stream_recv(ep, recv_buf, size)
            end
            t_end = Base.time_ns()
        else
            for i in -skip:loop
                UCX.stream_recv(ep, recv_buf, size)
                UCX.stream_send(ep, send_buf, size)
            end
        end

        if myid == 0
            t_delta = t_end-t_start
            t_op = t_delta / (2*loop)
            @info "Latency benchmark" time=prettytime(t_op) size
        end
        size *= 2 
    end
    exit(1)
end

function start_server()
    ctx = UCX.UCXContext()
    worker = UCX.UCXWorker(ctx)

    function listener_callback(conn_request_h::UCX.API.ucp_conn_request_h, args::Ptr{Cvoid})
        conn_request = UCX.UCXConnectionRequest(conn_request_h)
        Threads.@spawn begin
            try 
                benchmark(UCX.UCXEndpoint($worker, $conn_request), 0)
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

    benchmark(ep, 1)
end

if !isinteractive()
    @assert length(ARGS) == 1 "Expected command line argument role: 'client', 'server"
    kind = ARGS[1]
    if kind == "server"
        start_server()
    elseif kind == "client"
        start_client()
    end
end
