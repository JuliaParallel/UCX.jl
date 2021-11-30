# Run the benchmarks

## Setup
```
julia --project=examples/benchmarks
pkg> dev .
```

## Running

### MPI benchmarks (TCP)

```
julia --project=examples/benchmarks -e 'ENV["JULIA_MPI_BINARY"]="system"; using Pkg; Pkg.build("MPI"; verbose=true)'
mpiexec --mca btl tcp,self -n 2 julia --project=examples/benchmarks examples/benchmarks/mpi/latency.jl
```



```
JULIA_PROJECT=(pwd)/examples/benchmarks julia  examples/benchmarks/legacy/latency.jl
```
