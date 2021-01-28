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
        launch(n) = run(pipeline(`$cmd $script test $n`, stderr=stderr, stdout=stdout), wait=false)
        @test success(launch(1))
        @test success(launch(2))
        @test success(launch(3))
    end

    @testset "Client-Server Stream" begin
        script = joinpath(examples_dir, "client_server_stream.jl")
        launch(n) = run(pipeline(`$cmd $script test $n`, stderr=stderr, stdout=stdout), wait=false)
        @test success(launch(1))
        @test success(launch(2))
        @test success(launch(3))
    end
end
