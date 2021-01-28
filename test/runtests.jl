using Test
using UCX


@testset "examples" begin
    examples_dir = joinpath(@__DIR__, "..", "examples")
    cmd = Base.julia_cmd()
    if Base.JLOptions().project != C_NULL
        cmd = `$cmd --project=$(unsafe_string(Base.JLOptions().project))`
    end

    @testset "Client-Server" begin
        script = joinpath(examples_dir, "client_server.jl")
        launch(role, n=1) = run(pipeline(`$cmd $script $role $n`, stderr=stderr), wait=false)
        server = launch("server")
        client = launch("client")

        @test success(client)
        @test success(server)
    end
end
