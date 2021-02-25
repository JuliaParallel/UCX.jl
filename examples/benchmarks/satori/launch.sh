#!/bin/bash
# Begin SLURM Directives
#SBATCH --job-name=UCX
#SBATCH --time=1:00:00
#SBATCH --mem=0
#SBATCH --ntasks-per-node=1
#SBATCH --gpus-per-node=0
#SBATCH --cpus-per-task=1

# Clear the environment from any previously loaded modules
module purge > /dev/null 2>&1

module add spack

module load julia/1.5.3
module load cuda/10.1.243

spack env activate pappa
export UCX_LOG_LEVEL=debug

export HOME2=/nobackup/users/vchuravy

export JULIA_PROJECT=`pwd`
export JULIA_DEPOT_PATH=${HOME2}/julia_depot

export JULIA_CUDA_USE_BINARYBUILDER=false

julia -e 'using Pkg; pkg"instantiate"'
julia -e 'using Pkg; pkg"precompile"'

UCX_TLS=all julia -L setup.jl ../legacy/latency.jl 
UCX_TLS=tcp,self julia -L setup.jl ../legacy/latency.jl tcp
UCX_TLS=ib,self julia -L setup.jl ../legacy/latency.jl ib
UCX_TLS=ib,self julia -L setup.jl ../legacy/latency_cuda.jl
julia -L setup.jl ../distributed/latency.jl
