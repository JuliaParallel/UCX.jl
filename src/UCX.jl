module UCX

include("api.jl")

function version()
    major = Ref{Cuint}()
    minor = Ref{Cuint}()
    patch = Ref{Cuint}()
    API.ucp_get_version(major, minor, patch)
    VersionNumber(major[], minor[], patch[])
end

function __init__()
    lib_ver = version()
    api_ver = VersionNumber(API.UCP_API_MAJOR, 
                            API.UCP_API_MINOR,
                            lib_ver.patch)
    # TODO: Support multiple library versions in one package.
    @assert lib_ver === api_ver
end

end
