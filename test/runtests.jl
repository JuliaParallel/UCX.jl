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

@testset "query" begin
    # TODO support other builds
    UCX.max_thread_level() == UCX.API.UCS_THREAD_MODE_MULTI
end

@testset "context" begin
    ctx = UCX.UCXContext(TLS="tcp")
    @test ctx.config[:TLS] == "tcp"

    @test UCX.thread_mode(UCX.UCXContext(; shared=false)) == UCX.API.UCS_THREAD_MODE_SINGLE
    @test UCX.thread_mode(UCX.UCXContext(; shared=true)) == UCX.API.UCS_THREAD_MODE_MULTI
end

@testset "Worker" begin
    worker = UCX.UCXWorker(UCX.UCXContext())

    UCX.thread_mode(worker) == UCX.API.UCS_THREAD_MODE_MULTI
    UCX.max_am_header(worker) > 0

    worker = UCX.UCXWorker(UCX.UCXContext(; am = false))
    UCX.max_am_header(worker) == 0
end

@testset "progress" begin
    using UCX
    UCX.PROGRESS_MODE[] = :polling
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

@testset "address" begin
    ctx = UCX.UCXContext()
    worker = UCX.UCXWorker(ctx)
    addr = UCX.UCXAddress(worker)
    @test addr.len > 0
end

@testset "Active Messages" begin
    cmd = Base.julia_cmd()
    if Base.JLOptions().project != C_NULL
        cmd = `$cmd --project=$(unsafe_string(Base.JLOptions().project))`
    end
    setup  = joinpath(@__DIR__, "setup.jl")
    script = joinpath(@__DIR__, "am.jl")
    @test success(pipeline(`$cmd -L setup.jl $script`, stderr=stderr, stdout=stdout))
    withenv("JLUCX_PROGRESS_MODE" => "busy") do
        @test success(pipeline(`$cmd -L setup.jl $script`, stderr=stderr, stdout=stdout))
        # @test success(pipeline(`$cmd -t 2 -L setup.jl $script`, stderr=stderr, stdout=stdout))
    end
    withenv("JLUCX_PROGRESS_MODE" => "polling") do
        @test success(pipeline(`$cmd -L setup.jl $script`, stderr=stderr, stdout=stdout))
    end
    withenv("JLUCX_PROGRESS_MODE" => "unknown") do
        @test !success(pipeline(`$cmd -L setup.jl $script`, stderr=Base.DevNull(), stdout=Base.DevNull()))
    end
    withenv("AM_TEST_REPLY_EP" => "true") do
        @test success(pipeline(`$cmd -L setup.jl $script`, stderr=stderr, stdout=stdout))
    end
end

@testset "Remote Memory Access" begin
    cmd = Base.julia_cmd()
    if Base.JLOptions().project != C_NULL
        cmd = `$cmd --project=$(unsafe_string(Base.JLOptions().project))`
    end
    setup  = joinpath(@__DIR__, "setup.jl")
    script = joinpath(@__DIR__, "rma.jl")
    @test success(pipeline(`$cmd -L setup.jl $script`, stderr=stderr, stdout=stdout))
    withenv("JLUCX_PROGRESS_MODE" => "busy") do
        @test success(pipeline(`$cmd -L setup.jl $script`, stderr=stderr, stdout=stdout))
    end
    withenv("JLUCX_PROGRESS_MODE" => "polling") do
        @test success(pipeline(`$cmd -L setup.jl $script`, stderr=stderr, stdout=stdout))
    end
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
