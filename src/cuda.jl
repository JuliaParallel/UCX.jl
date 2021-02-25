import .CUDA

function Base.cconvert(::Type{UCXPtr}, buf::CUDA.CuArray{T}) where T
    Base.cconvert(CUDA.CuPtr{T}, buf) # returns DeviceBuffer
end

function Base.unsafe_convert(::Type{UCXPtr}, X::CUDA.CuArray{T}) where T
    reinterpret(UCXPtr, Base.unsafe_convert(CUDA.CuPtr{T}, X))
end

UCX.Legacy.direct(::CUDA.CuArray{T}) where T = isbitstype(T)
function UCX.Legacy.alloc_func(arg::CUDA.CuArray{T,N}) where {T,N}
    shape = size(arg)
    ()->CUDA.CuArray{T, N}(undef, shape)
end

function UCX.unsafe_copyto!(out::CUDA.CuArray, in)
    # XXX: It seems that these are always host buffers
    inbuf = unsafe_wrap(Array, Base.unsafe_convert(Ptr{UInt8}, in), sizeof(out))
    copyto!(out, inbuf)

    # GC.@preserve out begin
    #     ptr = pointer(out)
    #     ptr = Base.unsafe_convert(CUDA.CuPtr{UInt8}, ptr)
    #     in = Base.reinterpret(CUDA.CuPtr{UInt8}, in)
    #     Base.unsafe_copyto!(ptr, in, sizeof(out))
    # end
end

UCX.memory_type(::Union{CUDA.CuArray, CUDA.CuPtr}) = UCX.API.UCS_MEMORY_TYPE_CUDA