using CairoMakie
using TypedTables
using CSV

# Latency

dist_latency = Table(CSV.File("distributed/latency.csv"))
legacy_latency = Table(CSV.File("legacy/latency_tcp.csv"))
ucx_latency = Table(CSV.File("ucx/latency_tcp.csv"))
mpi_latency = Table(CSV.File("mpi/latency.csv"))

let
    f = Figure()
    fig = f[1, 1] = Axis(f)
    fig.xlabel = "Message size (bytes)"
    fig.ylabel = "Latency (ns)"

    lines!(dist_latency.msg_size, dist_latency.latency, label = "Distributed", linewidth = 2, color=:red)
    lines!(legacy_latency.msg_size, legacy_latency.latency, label = "Distributed over UCX", linewidth = 2, color=:blue)
    lines!(ucx_latency.msg_size, ucx_latency.latency, label = "UCX", linewidth = 2, color=:green)
    lines!(mpi_latency.msg_size, mpi_latency.latency, label = "MPI", linewidth = 2, color=:black)

    f[1, 2] = Legend(f, fig)
    f
    save("latency.png", f)
end
