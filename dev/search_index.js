var documenterSearchIndex = {"docs":
[{"location":"api/#API","page":"API","title":"API","text":"","category":"section"},{"location":"api/","page":"API","title":"API","text":"Modules = [UCX]","category":"page"},{"location":"api/#UCX.AMHandler","page":"API","title":"UCX.AMHandler","text":"AMHandler(func)\n\nArguments to callback\n\nworker::UCXWorker\ndata::Ptr{Cvoid}\nlength::Csize_t\nreply_ep::API.ucp_ep_h\nflags::Cuint\n\nReturn values\n\nThe callback func needs to return either UCX.API.UCS_OK or UCX.API.UCS_INPROGRESS. If it returns UCX.API.UCS_INPROGRESS it must call am_data_release(worker, data), or call am_recv.\n\n\n\n\n\n","category":"type"},{"location":"api/#UCX.progress","page":"API","title":"UCX.progress","text":"progress(worker::UCXWorker)\n\nAllows worker to make progress, this includes finalizing requests and call callbacks.\n\nReturns true if progress was made, false if no work was waiting.\n\n\n\n\n\n","category":"function"},{"location":"#UCX.jl","page":"Home","title":"UCX.jl","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"This packages wraps UCX","category":"page"}]
}