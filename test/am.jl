using Test

# Assumes wireup has already happened, see setup.jl

@everywhere using UCX

@everywhere begin

const AM_RECEIVE = 1
function am_receive(worker, header, header_length, data, length, _param)
    param = Base.unsafe_load(_param)::UCX.API.ucp_am_recv_param_t
    # @assert (param.recv_attr & UCX.API.UCP_AM_RECV_ATTR_FIELD_REPLY_EP) != 0
    # ep = UCX.UCXEndpoint(worker, param.reply_ep)

    @assert header_length == sizeof(Int)
    id = Base.unsafe_load(Base.unsafe_convert(Ptr{Int}, header))

    UCX.@async_showerr begin
        ep = proc_to_endpoint(1)
        header = Ref{Int}(id)
        req = UCX.am_send(ep, AM_ANSWER, header)
        wait(req)
    end
    return UCX.API.UCS_OK
end
UCX.AMHandler(UCX_WORKER, am_receive, AM_RECEIVE) 

const reply_ch = Channel{Int}(0) # unbuffered
const AM_ANSWER = 2
function am_answer(worker, header, header_length, data, length, param)
    @assert header_length == sizeof(Int)
    id = Base.unsafe_load(Base.unsafe_convert(Ptr{Int}, header))
    UCX.@async_showerr put!(reply_ch, id) # XXX: Is the task here necessary?
    return UCX.API.UCS_OK
end
UCX.AMHandler(UCX_WORKER, am_answer,  AM_ANSWER)

end #@everywhere

const msg_counter = Ref{Int}(0)

function send()
    ep = proc_to_endpoint(2)

    # Get the next message id
    id = msg_counter[]
    time_start = Base.time_ns()

    # XXX: Switch to FLAG_REPLY with UCX 1.10-rc5
    # see https://github.com/openucx/ucx/issues/6394
    # req = UCX.am_send(ep, AM_RECEIVE, header, nothing, UCX.API.UCP_AM_SEND_FLAG_REPLY)
    req = UCX.am_send(ep, AM_RECEIVE, msg_counter)
    wait(req) # wait on request to be send before suspending in `take!`

    msg_counter[] += 1
    oid = take!(reply_ch)
    time_end = Base.time_ns()
    # We are timing the round-trip time intentionally
    # E.g. how long it takes for us to be notified

    @assert oid == id
    time_end - time_start
end

function bench(n)
    start_times = UInt64[]
    for i in 1:n
        push!(start_times, send())
    end
    start_times
end

bench(10)