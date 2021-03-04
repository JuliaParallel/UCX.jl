#!/bin/bash

# UCX_TLS=all julia -L setup.jl ../legacy/latency.jl 
# UCX_TLS=tcp,self julia -L setup.jl ../legacy/latency.jl tcp
# UCX_TLS=ib,self julia -L setup.jl ../legacy/latency.jl ib
# UCX_TLS=ib,self julia -L setup.jl ../legacy/latency_cuda.jl

export JULIA_WORKER_TIMEOUT=180

flux mini run --nodes=1 --ntasks=2 julia -L setup.jl ../legacy/latency.jl 
flux mini run --nodes=1 --ntasks=2 julia -L setup.jl ../legacy/latency_cuda.jl
flux mini run --nodes=1 --ntasks=2 julia -L setup.jl ../distributed/latency.jl
flux mini run --nodes=1 --ntasks=2 julia -L setup.jl ../distributed/latency_cuda.jl