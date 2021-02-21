using Test
using UCX

@testset "config" begin
    config = UCX.UCXConfig(TLS="tcp")
    @test parse(Dict, config)[:TLS] == "tcp"

    config[:TLS] = "all"
    @test parse(Dict, config)[:TLS] == "all"

    ctx = UCX.UCXContext(TLS="tcp")
    @test ctx.config[:TLS] == "tcp"
end

@testset "progress" begin
    using UCX
    ctx = UCX.UCXContext()
    worker = UCX.UCXWorker(ctx)

    flag = Ref(false)
    T = UCX.@async_showerr begin
        wait(worker)
        flag[] = true
    end
    while !flag[]
        notify(worker)
        yield()
    end
    wait(T)
    @test flag[]
end


@testset "examples" begin
    examples_dir = joinpath(@__DIR__, "..", "examples")
    cmd = Base.julia_cmd()
    if Base.JLOptions().project != C_NULL
        cmd = `$cmd --project=$(unsafe_string(Base.JLOptions().project))`
    end

    @testset "Client-Server" begin
        script = joinpath(examples_dir, "client_server.jl")
        for i in 0:2
            @test success(pipeline(`$cmd $script test $(2^i)`, stderr=stderr, stdout=stdout))
        end
    end

    @testset "Client-Server Stream" begin
        script = joinpath(examples_dir, "client_server_stream.jl")
        for i in 0:2
            @test success(pipeline(`$cmd $script test $(2^i)`, stderr=stderr, stdout=stdout))
        end
    end
end
