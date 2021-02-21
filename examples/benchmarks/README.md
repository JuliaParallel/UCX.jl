# Run the benchmarks

## Setup
```
julia --project=examples/benchmarks
pkg> dev .
```

## Running
```
JULIA_PROJECT=(pwd)/examples/benchmarks julia  examples/benchmarks/legacy/latency.jl
```