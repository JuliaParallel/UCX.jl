function idle_callback(handle)
    idle = @Base.handle_as handle UvWorkerIdle
    if isopen(idle.worker)
        progress(idle.worker)
    else
        close(idle)
    end
    nothing
end

mutable struct UvWorkerIdle
    handle::Ptr{Cvoid}
    cond::Base.ThreadSynchronizer
    worker::UCXWorker
    isopen::Bool

    function UvWorkerIdle(worker::UCXWorker)
        this = new(Libc.malloc(Base._sizeof_uv_idle), Base.ThreadSynchronizer(), worker, true)
        Base.iolock_begin()
        Base.associate_julia_struct(this.handle, this)
        err = ccall(:uv_idle_init, Cint, (Ptr{Cvoid}, Ptr{Cvoid}),
            Base.eventloop(), this.handle)
        if err != 0
            Libc.free(this.handle)
            this.handle = C_NULL
            throw(_UVError("uv_idle_init", err))
        end
        err = ccall(:uv_idle_start, Cint, (Ptr{Cvoid}, Ptr{Cvoid}),
            this.handle, @cfunction(idle_callback, Cvoid, (Ptr{Cvoid},)))
        if err != 0
            Libc.free(this.handle)
            this.handle = C_NULL
            throw(_UVError("uv_idle_start", err))
        end
        finalizer(Base.uvfinalize, this)
        Base.iolock_end()
        return this
    end
end
Base.unsafe_convert(::Type{Ptr{Cvoid}}, idle::UvWorkerIdle) = idle.handle

function Base.uvfinalize(t::UvWorkerIdle)
    Base.iolock_begin()
    Base.lock(t.cond)
    try
        if t.handle != C_NULL
            Base.disassociate_julia_struct(t.handle) # not going to call the usual close hooks
            if t.isopen
                t.isopen = false
                ccall(:jl_close_uv, Cvoid, (Ptr{Cvoid},), t)
            end
            t.handle = C_NULL
            notify(t.cond, false)
        end
    finally
        unlock(t.cond)
    end
    Base.iolock_end()
    nothing
end

function Base.close(idle::UvWorkerIdle)
    Base.uvfinalize(idle)
end

function Base.wait(idle::UvWorkerIdle)
    Base.iolock_begin()
    Base.preserve_handle(idle)
    Base.lock(idle.cond)
    try
        Base.iolock_end()
        wait(idle.cond)
    finally
        Base.unlock(idle.cond)
        Base.iolock_begin()
        Base.unpreserve_handle(idle)
        Base.iolock_end()
    end
end
