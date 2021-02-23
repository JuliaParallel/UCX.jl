using Distributed

include(joinpath(@__DIR__, "..", "config.jl"))

addprocs(1)

@everywhere using UCX
@everywhere UCX.Legacy.wireup()

@everywhere function target(A)
    nothing
end

const MAX_MESSAGE_SIZE = 1<<22
# const MAX_MESSAGE_SIZE = 4096
const LARGE_MESSAGE_SIZE = 8192

const LAT_LOOP_SMALL = 10000
const LAT_SKIP_SMALL = 100
const LAT_LOOP_LARGE = 1000
const LAT_SKIP_LARGE = 10

function touch_data(send_buf, size)
    send_buf[1:size] .= 'A' % UInt8
end

function benchmark()
    t = Table(msg_size = Int[], latency = Float64[], kind=Symbol[])
    send_buf = Vector{UInt8}(undef, MAX_MESSAGE_SIZE)

    size = 1
    while size <= MAX_MESSAGE_SIZE
        @info "sending" size
        flush(stderr)
        touch_data(send_buf, size)

        if size > LARGE_MESSAGE_SIZE
            loop = LAT_LOOP_LARGE
            skip = LAT_SKIP_LARGE
        else
            loop = LAT_LOOP_SMALL
            skip = LAT_SKIP_SMALL
        end

        t_start = 0
        for i in -skip:loop
            if i == 1
                t_start = Base.time_ns()
            end

            GC.@preserve send_buf begin
                ptr = pointer(send_buf)
                subset = Base.unsafe_wrap(Array, ptr, size)
                # avoid view
                UCX.Legacy.remotecall_wait(target, 2, subset)
            end

        end
        t_end = Base.time_ns()

        t_delta = t_end-t_start
        t_op = t_delta / loop

        push!(t, (msg_size = size, latency = t_op, kind = :distributed))

        size *= 2 
    end

    CSV.write(joinpath(@__DIR__, "latency.csv"), t)
end

if !isinteractive()
    benchmark()
end
