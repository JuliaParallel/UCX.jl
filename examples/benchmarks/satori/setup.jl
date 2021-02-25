using Distributed


# Usage:
# - Set `export JULIA_PROJECT=`pwd``

# using ClusterManagers
# if haskey(ENV, "SLURM_JOB_ID")
#   jobid = ENV["SLURM_JOB_ID"]  
#   ntasks = parse(Int, ENV["SLURM_NTASKS"])
#   cpus_per_task = parse(Int, ENV["SLURM_CPUS_PER_TASK"])
#   @info "Running on Slurm cluster" jobid ntasks cpus_per_task
#   manager = SlurmManager(ntasks)
# else
#   ntasks = 2
#   cpus_per_task = div(Sys.CPU_THREADS, ntasks)
#   @info "Running locally" ntasks
#   manager = Distributed.LocalManager(ntasks, false)
# end
# flush(stderr)

# addprocs(manager; exeflags = ["-t $cpus_per_task"])

@info "Using PMI"
using PMI

include(joinpath(dirname(pathof(PMI)), "..", "examples", "distributed.jl"))
WireUp.wireup()

@everywhere ENV["CUDA_VISIBLE_DEVICES"] = myid()

@everywhere begin
  import Dates
  using Logging, LoggingExtras
  const date_format = "HH:MM:SS"

  function distributed_logger(logger)
    logger = MinLevelLogger(logger, Logging.Info)
    logger = TransformerLogger(logger) do log
      merge(log, (; message = "$(Dates.format(Dates.now(), date_format)) ($(myid())) $(log.message)"))
    end
    return logger
  end

  # set the global logger
  if !(stderr isa IOStream)
    ConsoleLogger(stderr)
  else
    FileLogger(stderr, always_flush=true)
  end |> distributed_logger |> global_logger
end

@everywhere begin
  if myid() != 1
    @info "Worker started" Base.Threads.nthreads()
  end
  sysimg = unsafe_string((Base.JLOptions()).image_file)
  project = Base.active_project()
  host = strip(read(`hostname`, String))
  @info "Environment" sysimg project host
end
