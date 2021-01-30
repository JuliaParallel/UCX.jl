using CairoMakie
using TypedTables
using CSV

# Latency

dist_latency = Table(CSV.File("distributed/latency.csv"))
ucx_latency = Table(CSV.File("ucx/latency.csv"))
mpi_latency = Table(CSV.File("mpi/latency.csv"))

let
    f = Figure()
    fig = f[1, 1] = Axis(f, palette = (color = [:black],))
    fig.xlabel = "Message size (bytes)"
    fig.ylabel = "Latency (ns)"

    lines!(dist_latency.msg_size, dist_latency.latency, label = "Distributed", linewidth = 2)
    lines!(ucx_latency.msg_size, ucx_latency.latency, label = "UCX", linewidth = 2)
    lines!(mpi_latency.msg_size, mpi_latency.latency, label = "MPI", linewidth = 2)

    f[1, 2] = Legend(f, fig)
    f
end