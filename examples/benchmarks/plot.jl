using CairoMakie
using TypedTables
using CSV
using Printf

# Latency

am_n2_latency = Table(CSV.File("legacy/latency_n2.csv"))
am_n1_latency = Table(CSV.File("legacy/latency_n1.csv"))
am_gpu_n2_latency = Table(CSV.File("legacy/latency_cuda_n2.csv"))
am_gpu_n1_latency = Table(CSV.File("legacy/latency_cuda_n1.csv"))
dist_n2_latency = Table(CSV.File("distributed/latency_n2.csv"))
dist_n1_latency = Table(CSV.File("distributed/latency_n1.csv"))
dist_gpu_n2_latency = Table(CSV.File("distributed/latency_cuda_n2.csv"))
dist_gpu_n1_latency = Table(CSV.File("distributed/latency_cuda_n1.csv"))

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
    t = exp10(t)
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


function vis(f, label, am, dist)

    fig = Axis(f, xticks = LinearTicks(16), yticks=LinearTicks(10),
                         xtickformat = ticks -> bytes_label.(ticks),
                         ytickformat = ticks -> prettytime.(ticks))
    fig.xlabel = "Message size (bytes) - Logscale"
    fig.ylabel = "Latency - Logscale"
    fig.title = label

    lines!(log.(2, dist.msg_size), log.(10, dist.latency), label = "Distributed", linewidth = 2, color=:red)
    lines!(log.(2, am.msg_size), log.(10, am.latency), label = "UCX", linewidth = 2, color=:blue)

    axislegend(position=:lt)
    fig
end

f = Figure(resolution = (2000, 1600))
f[1, 1] = cpu1 = vis(f, "Single Node CPU Latency", am_n1_latency, dist_n1_latency)
f[2, 1] = gpu1 = vis(f, "Single Node GPU Latency", am_gpu_n1_latency, dist_gpu_n1_latency)
f[1, 2] = cpu2 = vis(f, "Two Node CPU Latency", am_n2_latency, dist_n2_latency)
f[2, 2] = gpu2 =vis(f, "Two Node GPU Latency", am_gpu_n2_latency, dist_gpu_n2_latency)

linkyaxes!(cpu1, cpu2)
linkyaxes!(gpu1, gpu2)
linkxaxes!(cpu1, cpu2, gpu1, gpu2)

Label(f[0, :], "Latency test on IBM Power9 & NVidia V100", textsize = 30)
f
save("latency.png", f)
