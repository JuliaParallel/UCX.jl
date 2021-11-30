using CairoMakie
using TypedTables
using CSV
using Printf

# Latency

dist_latency = Table(CSV.File("distributed/latency.csv"))
legacy_latency = Table(CSV.File("legacy/latency_tcp.csv"))
amarg_latency = Table(CSV.File("legacy/latency_amarg.csv"))
ucx_latency = Table(CSV.File("ucx/latency_tcp.csv"))
mpi_latency = Table(CSV.File("mpi/latency.csv"))

function bytes_label(bytes)
    bytes = 2^round(Int, bytes) # data in log space
    if bytes < 1024
        return string(bytes)
    else
        bytes = bytes ÷ 1024
    end
    if bytes < 1024
        return string(bytes, 'K')
    else
        bytes = bytes ÷ 1024
    end
    return string(bytes, 'M')
end

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
    return string(@sprintf("%.1f", value), " ", units)
end

let
    f = Figure(resolution = (1200, 900))
    fig = f[1, 1] = Axis(f, xticks = LinearTicks(16),
                         xtickformat = ticks -> bytes_label.(ticks),
                         ytickformat = ticks -> prettytime.(ticks))
    fig.xlabel = "Message size (bytes)"
    fig.ylabel = "Latency"

    lines!(log.(2, dist_latency.msg_size), dist_latency.latency, label = "Distributed", linewidth = 2, color=:red)
    lines!(log.(2, amarg_latency.msg_size), amarg_latency.latency, label = "Distributed (UCX)", linewidth = 2, color=:cyan)
    lines!(log.(2, ucx_latency.msg_size), ucx_latency.latency, label = "Raw UCX", linewidth = 2, color=:green)
    lines!(log.(2, mpi_latency.msg_size), mpi_latency.latency, label = "MPI", linewidth = 2, color=:black)

    f[1, 2] = Legend(f, fig)
    f
    save("latency.png", f)
end
