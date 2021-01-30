using MPI
using Sockets

include(joinpath(@__DIR__, "..", "config.jl"))

# mpiexec() do cmd
#     run(`$cmd -n 2 $(Base.julia_cmd()) --project=examples/benchmarks examples/benchmarks/mpi/latency.jl`)
# end

# Inspired by OSU Microbenchmark latency test
function touch_data(send_buf, recv_buf, size)
    send_buf[1:size] .= 'A' % UInt8
    recv_buf[1:size] .= 'B' % UInt8
end

function benchmark()
    MPI.Init()
    myid = MPI.Comm_rank(MPI.COMM_WORLD)

    recv_buf = Vector{UInt8}(undef, MAX_MESSAGE_SIZE)
    send_buf = Vector{UInt8}(undef, MAX_MESSAGE_SIZE)

    t = Table(msg_size = Int[], latency = Float64[], kind=Symbol[])
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

        MPI.Barrier(MPI.COMM_WORLD)

        t_start = 0
        t_end = 0
        if myid == 0
            for i in -skip:loop
                if i == 1
                    t_start = Base.time_ns()
                end

                MPI.Send(view(send_buf, 1:size), 1, 1, MPI.COMM_WORLD)
                MPI.Recv!(view(recv_buf, 1:size), 1, 1, MPI.COMM_WORLD)
            end
            t_end = Base.time_ns()
        else
            for i in -skip:loop
                MPI.Recv!(view(recv_buf, 1:size), 0, 1, MPI.COMM_WORLD)
                MPI.Send(view(send_buf, 1:size), 0, 1, MPI.COMM_WORLD)
            end
        end

        if myid == 0
            t_delta = t_end-t_start
            t_op = t_delta / (2*loop)

            push!(t, (msg_size = size, latency = t_op, kind=:mpi))
        end
        size *= 2 
    end

    if myid == 0
        CSV.write(joinpath(@__DIR__, "latency.csv"), t)
    end

    exit()
end

if !isinteractive()
   benchmark() 
end
