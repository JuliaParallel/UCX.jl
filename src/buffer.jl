UCXBuffertype{T} = Union{Ptr{T}, Array{T}, Ref{T}}

Base.cconvert(::Type{UCXPtr}, x::Union{Ptr{T}, Array{T}, Ref{T}}) where T = Base.cconvert(Ptr{T}, x)
function Base.unsafe_convert(::Type{UCXPtr}, x::UCXBuffertype{T}) where T
    ptr = Base.unsafe_convert(Ptr{T}, x)
    reinterpret(UCXPtr, ptr)
end

function Base.cconvert(::Type{UCXPtr}, x::String)
    x
end
function Base.unsafe_convert(::Type{UCXPtr}, x::String)
    reinterpret(MPIPtr, pointer(x))
end

# TODO: alignment & datatype...
function unsafe_copyto!(out::UCXBuffertype, in)
    GC.@preserve out begin
        ptr = Base.unsafe_convert(Ptr{Cvoid}, Base.cconvert(Ptr{Cvoid}, out))
        ptr = Base.unsafe_convert(Ptr{UInt8}, ptr)
        in = Base.unsafe_convert(Ptr{UInt8}, in)
        Base.unsafe_copyto!(ptr, in, sizeof(out))
    end
end

memory_type(::UCXBuffertype) = UCX.API.UCS_MEMORY_TYPE_HOST