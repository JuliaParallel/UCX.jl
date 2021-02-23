using Distributed
using Test

addprocs(1)

@everywhere using UCX
@everywhere UCX.Legacy.wireup()

@test fetch(UCX.Legacy.remotecall(()->true, 2))
@test UCX.Legacy.remotecall_fetch(()->true, 2)

data = rand(8192)
UCX.Legacy.remotecall_wait(sum, 2, data) 
@test UCX.Legacy.remotecall_fetch(sum, 2, data) == sum(data)

@test UCX.Legacy.remotecall_fetch(()->true, 1)
@test fetch(UCX.Legacy.remotecall(()->true, 1))
