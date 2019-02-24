# Julia wrapper for header: /home/vchuravy/src/UCX.jl/deps/usr/include/ucp/api/ucp.h
# Automatically generated using Clang.jl wrap_c


function ucp_config_read(env_prefix, filename, config_p)
    ccall((:ucp_config_read, libucp), ucs_status_t, (Cstring, Cstring, Ptr{Ptr{ucp_config_t}}), env_prefix, filename, config_p)
end

function ucp_config_release(config)
    ccall((:ucp_config_release, libucp), Cvoid, (Ptr{ucp_config_t},), config)
end

function ucp_config_modify(config, name, value)
    ccall((:ucp_config_modify, libucp), ucs_status_t, (Ptr{ucp_config_t}, Cstring, Cstring), config, name, value)
end

function ucp_config_print(config, stream, title, print_flags)
    ccall((:ucp_config_print, libucp), Cvoid, (Ptr{ucp_config_t}, Ptr{FILE}, Cstring, ucs_config_print_flags_t), config, stream, title, print_flags)
end

function ucp_get_version(major_version, minor_version, release_number)
    ccall((:ucp_get_version, libucp), Cvoid, (Ptr{UInt32}, Ptr{UInt32}, Ptr{UInt32}), major_version, minor_version, release_number)
end

function ucp_get_version_string()
    ccall((:ucp_get_version_string, libucp), Cstring, ())
end

function ucp_init_version(api_major_version, api_minor_version, params, config, context_p)
    ccall((:ucp_init_version, libucp), ucs_status_t, (UInt32, UInt32, Ptr{ucp_params_t}, Ptr{ucp_config_t}, Ptr{ucp_context_h}), api_major_version, api_minor_version, params, config, context_p)
end

function ucp_init(params, config, context_p)
    ccall((:ucp_init, libucp), ucs_status_t, (Ptr{ucp_params_t}, Ptr{ucp_config_t}, Ptr{ucp_context_h}), params, config, context_p)
end

function ucp_cleanup(context_p)
    ccall((:ucp_cleanup, libucp), Cvoid, (ucp_context_h,), context_p)
end

function ucp_context_query(context_p, attr)
    ccall((:ucp_context_query, libucp), ucs_status_t, (ucp_context_h, Ptr{ucp_context_attr_t}), context_p, attr)
end

function ucp_context_print_info(context, stream)
    ccall((:ucp_context_print_info, libucp), Cvoid, (ucp_context_h, Ptr{FILE}), context, stream)
end

function ucp_worker_create(context, params, worker_p)
    ccall((:ucp_worker_create, libucp), ucs_status_t, (ucp_context_h, Ptr{ucp_worker_params_t}, Ptr{ucp_worker_h}), context, params, worker_p)
end

function ucp_worker_destroy(worker)
    ccall((:ucp_worker_destroy, libucp), Cvoid, (ucp_worker_h,), worker)
end

function ucp_worker_query(worker, attr)
    ccall((:ucp_worker_query, libucp), ucs_status_t, (ucp_worker_h, Ptr{ucp_worker_attr_t}), worker, attr)
end

function ucp_worker_print_info(worker, stream)
    ccall((:ucp_worker_print_info, libucp), Cvoid, (ucp_worker_h, Ptr{FILE}), worker, stream)
end

function ucp_worker_get_address(worker, address_p, address_length_p)
    ccall((:ucp_worker_get_address, libucp), ucs_status_t, (ucp_worker_h, Ptr{Ptr{ucp_address_t}}, Ptr{Csize_t}), worker, address_p, address_length_p)
end

function ucp_worker_release_address(worker, address)
    ccall((:ucp_worker_release_address, libucp), Cvoid, (ucp_worker_h, Ptr{ucp_address_t}), worker, address)
end

function ucp_worker_progress(worker)
    ccall((:ucp_worker_progress, libucp), UInt32, (ucp_worker_h,), worker)
end

function ucp_stream_worker_poll(worker, poll_eps, max_eps, flags)
    ccall((:ucp_stream_worker_poll, libucp), ssize_t, (ucp_worker_h, Ptr{ucp_stream_poll_ep_t}, Csize_t, UInt32), worker, poll_eps, max_eps, flags)
end

function ucp_worker_get_efd(worker, fd)
    ccall((:ucp_worker_get_efd, libucp), ucs_status_t, (ucp_worker_h, Ptr{Cint}), worker, fd)
end

function ucp_worker_wait(worker)
    ccall((:ucp_worker_wait, libucp), ucs_status_t, (ucp_worker_h,), worker)
end

function ucp_worker_wait_mem(worker, address)
    ccall((:ucp_worker_wait_mem, libucp), Cvoid, (ucp_worker_h, Ptr{Cvoid}), worker, address)
end

function ucp_worker_arm(worker)
    ccall((:ucp_worker_arm, libucp), ucs_status_t, (ucp_worker_h,), worker)
end

function ucp_worker_signal(worker)
    ccall((:ucp_worker_signal, libucp), ucs_status_t, (ucp_worker_h,), worker)
end

function ucp_listener_create(worker, params, listener_p)
    ccall((:ucp_listener_create, libucp), ucs_status_t, (ucp_worker_h, Ptr{ucp_listener_params_t}, Ptr{ucp_listener_h}), worker, params, listener_p)
end

function ucp_listener_destroy(listener)
    ccall((:ucp_listener_destroy, libucp), Cvoid, (ucp_listener_h,), listener)
end

function ucp_ep_create(worker, params, ep_p)
    ccall((:ucp_ep_create, libucp), ucs_status_t, (ucp_worker_h, Ptr{ucp_ep_params_t}, Ptr{ucp_ep_h}), worker, params, ep_p)
end

function ucp_ep_close_nb(ep, mode)
    ccall((:ucp_ep_close_nb, libucp), ucs_status_ptr_t, (ucp_ep_h, UInt32), ep, mode)
end

function ucp_listener_reject(listener, conn_request)
    ccall((:ucp_listener_reject, libucp), ucs_status_t, (ucp_listener_h, ucp_conn_request_h), listener, conn_request)
end

function ucp_ep_print_info(ep, stream)
    ccall((:ucp_ep_print_info, libucp), Cvoid, (ucp_ep_h, Ptr{FILE}), ep, stream)
end

function ucp_ep_flush_nb(ep, flags, cb)
    ccall((:ucp_ep_flush_nb, libucp), ucs_status_ptr_t, (ucp_ep_h, UInt32, ucp_send_callback_t), ep, flags, cb)
end

function ucp_mem_map(context, params, memh_p)
    ccall((:ucp_mem_map, libucp), ucs_status_t, (ucp_context_h, Ptr{ucp_mem_map_params_t}, Ptr{ucp_mem_h}), context, params, memh_p)
end

function ucp_mem_unmap(context, memh)
    ccall((:ucp_mem_unmap, libucp), ucs_status_t, (ucp_context_h, ucp_mem_h), context, memh)
end

function ucp_mem_query(memh, attr)
    ccall((:ucp_mem_query, libucp), ucs_status_t, (ucp_mem_h, Ptr{ucp_mem_attr_t}), memh, attr)
end

function ucp_mem_advise(context, memh, params)
    ccall((:ucp_mem_advise, libucp), ucs_status_t, (ucp_context_h, ucp_mem_h, Ptr{ucp_mem_advise_params_t}), context, memh, params)
end

function ucp_rkey_pack(context, memh, rkey_buffer_p, size_p)
    ccall((:ucp_rkey_pack, libucp), ucs_status_t, (ucp_context_h, ucp_mem_h, Ptr{Ptr{Cvoid}}, Ptr{Csize_t}), context, memh, rkey_buffer_p, size_p)
end

function ucp_rkey_buffer_release(rkey_buffer)
    ccall((:ucp_rkey_buffer_release, libucp), Cvoid, (Ptr{Cvoid},), rkey_buffer)
end

function ucp_ep_rkey_unpack(ep, rkey_buffer, rkey_p)
    ccall((:ucp_ep_rkey_unpack, libucp), ucs_status_t, (ucp_ep_h, Ptr{Cvoid}, Ptr{ucp_rkey_h}), ep, rkey_buffer, rkey_p)
end

function ucp_rkey_ptr(rkey, raddr, addr_p)
    ccall((:ucp_rkey_ptr, libucp), ucs_status_t, (ucp_rkey_h, UInt64, Ptr{Ptr{Cvoid}}), rkey, raddr, addr_p)
end

function ucp_rkey_destroy(rkey)
    ccall((:ucp_rkey_destroy, libucp), Cvoid, (ucp_rkey_h,), rkey)
end

function ucp_stream_send_nb(ep, buffer, count, datatype, cb, flags)
    ccall((:ucp_stream_send_nb, libucp), ucs_status_ptr_t, (ucp_ep_h, Ptr{Cvoid}, Csize_t, ucp_datatype_t, ucp_send_callback_t, UInt32), ep, buffer, count, datatype, cb, flags)
end

function ucp_tag_send_nb(ep, buffer, count, datatype, tag, cb)
    ccall((:ucp_tag_send_nb, libucp), ucs_status_ptr_t, (ucp_ep_h, Ptr{Cvoid}, Csize_t, ucp_datatype_t, ucp_tag_t, ucp_send_callback_t), ep, buffer, count, datatype, tag, cb)
end

function ucp_tag_send_nbr(ep, buffer, count, datatype, tag, req)
    ccall((:ucp_tag_send_nbr, libucp), ucs_status_t, (ucp_ep_h, Ptr{Cvoid}, Csize_t, ucp_datatype_t, ucp_tag_t, Ptr{Cvoid}), ep, buffer, count, datatype, tag, req)
end

function ucp_tag_send_sync_nb(ep, buffer, count, datatype, tag, cb)
    ccall((:ucp_tag_send_sync_nb, libucp), ucs_status_ptr_t, (ucp_ep_h, Ptr{Cvoid}, Csize_t, ucp_datatype_t, ucp_tag_t, ucp_send_callback_t), ep, buffer, count, datatype, tag, cb)
end

function ucp_stream_recv_nb(ep, buffer, count, datatype, cb, length, flags)
    ccall((:ucp_stream_recv_nb, libucp), ucs_status_ptr_t, (ucp_ep_h, Ptr{Cvoid}, Csize_t, ucp_datatype_t, ucp_stream_recv_callback_t, Ptr{Csize_t}, UInt32), ep, buffer, count, datatype, cb, length, flags)
end

function ucp_stream_recv_data_nb(ep, length)
    ccall((:ucp_stream_recv_data_nb, libucp), ucs_status_ptr_t, (ucp_ep_h, Ptr{Csize_t}), ep, length)
end

function ucp_tag_recv_nb(worker, buffer, count, datatype, tag, tag_mask, cb)
    ccall((:ucp_tag_recv_nb, libucp), ucs_status_ptr_t, (ucp_worker_h, Ptr{Cvoid}, Csize_t, ucp_datatype_t, ucp_tag_t, ucp_tag_t, ucp_tag_recv_callback_t), worker, buffer, count, datatype, tag, tag_mask, cb)
end

function ucp_tag_recv_nbr(worker, buffer, count, datatype, tag, tag_mask, req)
    ccall((:ucp_tag_recv_nbr, libucp), ucs_status_t, (ucp_worker_h, Ptr{Cvoid}, Csize_t, ucp_datatype_t, ucp_tag_t, ucp_tag_t, Ptr{Cvoid}), worker, buffer, count, datatype, tag, tag_mask, req)
end

function ucp_tag_probe_nb(worker, tag, tag_mask, remove, info)
    ccall((:ucp_tag_probe_nb, libucp), ucp_tag_message_h, (ucp_worker_h, ucp_tag_t, ucp_tag_t, Cint, Ptr{ucp_tag_recv_info_t}), worker, tag, tag_mask, remove, info)
end

function ucp_tag_msg_recv_nb(worker, buffer, count, datatype, message, cb)
    ccall((:ucp_tag_msg_recv_nb, libucp), ucs_status_ptr_t, (ucp_worker_h, Ptr{Cvoid}, Csize_t, ucp_datatype_t, ucp_tag_message_h, ucp_tag_recv_callback_t), worker, buffer, count, datatype, message, cb)
end

function ucp_put_nbi(ep, buffer, length, remote_addr, rkey)
    ccall((:ucp_put_nbi, libucp), ucs_status_t, (ucp_ep_h, Ptr{Cvoid}, Csize_t, UInt64, ucp_rkey_h), ep, buffer, length, remote_addr, rkey)
end

function ucp_put_nb(ep, buffer, length, remote_addr, rkey, cb)
    ccall((:ucp_put_nb, libucp), ucs_status_ptr_t, (ucp_ep_h, Ptr{Cvoid}, Csize_t, UInt64, ucp_rkey_h, ucp_send_callback_t), ep, buffer, length, remote_addr, rkey, cb)
end

function ucp_get_nbi(ep, buffer, length, remote_addr, rkey)
    ccall((:ucp_get_nbi, libucp), ucs_status_t, (ucp_ep_h, Ptr{Cvoid}, Csize_t, UInt64, ucp_rkey_h), ep, buffer, length, remote_addr, rkey)
end

function ucp_get_nb(ep, buffer, length, remote_addr, rkey, cb)
    ccall((:ucp_get_nb, libucp), ucs_status_ptr_t, (ucp_ep_h, Ptr{Cvoid}, Csize_t, UInt64, ucp_rkey_h, ucp_send_callback_t), ep, buffer, length, remote_addr, rkey, cb)
end

function ucp_atomic_post(ep, opcode, value, op_size, remote_addr, rkey)
    ccall((:ucp_atomic_post, libucp), ucs_status_t, (ucp_ep_h, ucp_atomic_post_op_t, UInt64, Csize_t, UInt64, ucp_rkey_h), ep, opcode, value, op_size, remote_addr, rkey)
end

function ucp_atomic_fetch_nb(ep, opcode, value, result, op_size, remote_addr, rkey, cb)
    ccall((:ucp_atomic_fetch_nb, libucp), ucs_status_ptr_t, (ucp_ep_h, ucp_atomic_fetch_op_t, UInt64, Ptr{Cvoid}, Csize_t, UInt64, ucp_rkey_h, ucp_send_callback_t), ep, opcode, value, result, op_size, remote_addr, rkey, cb)
end

function ucp_request_check_status(request)
    ccall((:ucp_request_check_status, libucp), ucs_status_t, (Ptr{Cvoid},), request)
end

function ucp_tag_recv_request_test(request, info)
    ccall((:ucp_tag_recv_request_test, libucp), ucs_status_t, (Ptr{Cvoid}, Ptr{ucp_tag_recv_info_t}), request, info)
end

function ucp_stream_recv_request_test(request, length_p)
    ccall((:ucp_stream_recv_request_test, libucp), ucs_status_t, (Ptr{Cvoid}, Ptr{Csize_t}), request, length_p)
end

function ucp_request_cancel(worker, request)
    ccall((:ucp_request_cancel, libucp), Cvoid, (ucp_worker_h, Ptr{Cvoid}), worker, request)
end

function ucp_stream_data_release(ep, data)
    ccall((:ucp_stream_data_release, libucp), Cvoid, (ucp_ep_h, Ptr{Cvoid}), ep, data)
end

function ucp_request_free(request)
    ccall((:ucp_request_free, libucp), Cvoid, (Ptr{Cvoid},), request)
end

function ucp_dt_create_generic(ops, context, datatype_p)
    ccall((:ucp_dt_create_generic, libucp), ucs_status_t, (Ptr{ucp_generic_dt_ops_t}, Ptr{Cvoid}, Ptr{ucp_datatype_t}), ops, context, datatype_p)
end

function ucp_dt_destroy(datatype)
    ccall((:ucp_dt_destroy, libucp), Cvoid, (ucp_datatype_t,), datatype)
end

function ucp_worker_fence(worker)
    ccall((:ucp_worker_fence, libucp), ucs_status_t, (ucp_worker_h,), worker)
end

function ucp_worker_flush_nb(worker, flags, cb)
    ccall((:ucp_worker_flush_nb, libucp), ucs_status_ptr_t, (ucp_worker_h, UInt32, ucp_send_callback_t), worker, flags, cb)
end
# Julia wrapper for header: /home/vchuravy/src/UCX.jl/deps/usr/include/ucp/api/ucp_compat.h
# Automatically generated using Clang.jl wrap_c


function ucp_request_is_completed(request)
    ccall((:ucp_request_is_completed, libucp), Cint, (Ptr{Cvoid},), request)
end

function ucp_request_release(request)
    ccall((:ucp_request_release, libucp), Cvoid, (Ptr{Cvoid},), request)
end

function ucp_ep_destroy(ep)
    ccall((:ucp_ep_destroy, libucp), Cvoid, (ucp_ep_h,), ep)
end

function ucp_disconnect_nb(ep)
    ccall((:ucp_disconnect_nb, libucp), ucs_status_ptr_t, (ucp_ep_h,), ep)
end

function ucp_request_test(request, info)
    ccall((:ucp_request_test, libucp), ucs_status_t, (Ptr{Cvoid}, Ptr{ucp_tag_recv_info_t}), request, info)
end

function ucp_ep_flush(ep)
    ccall((:ucp_ep_flush, libucp), ucs_status_t, (ucp_ep_h,), ep)
end

function ucp_worker_flush(worker)
    ccall((:ucp_worker_flush, libucp), ucs_status_t, (ucp_worker_h,), worker)
end

function ucp_put(ep, buffer, length, remote_addr, rkey)
    ccall((:ucp_put, libucp), ucs_status_t, (ucp_ep_h, Ptr{Cvoid}, Csize_t, UInt64, ucp_rkey_h), ep, buffer, length, remote_addr, rkey)
end

function ucp_get(ep, buffer, length, remote_addr, rkey)
    ccall((:ucp_get, libucp), ucs_status_t, (ucp_ep_h, Ptr{Cvoid}, Csize_t, UInt64, ucp_rkey_h), ep, buffer, length, remote_addr, rkey)
end

function ucp_atomic_add32(ep, add, remote_addr, rkey)
    ccall((:ucp_atomic_add32, libucp), ucs_status_t, (ucp_ep_h, UInt32, UInt64, ucp_rkey_h), ep, add, remote_addr, rkey)
end

function ucp_atomic_add64(ep, add, remote_addr, rkey)
    ccall((:ucp_atomic_add64, libucp), ucs_status_t, (ucp_ep_h, UInt64, UInt64, ucp_rkey_h), ep, add, remote_addr, rkey)
end

function ucp_atomic_fadd32(ep, add, remote_addr, rkey, result)
    ccall((:ucp_atomic_fadd32, libucp), ucs_status_t, (ucp_ep_h, UInt32, UInt64, ucp_rkey_h, Ptr{UInt32}), ep, add, remote_addr, rkey, result)
end

function ucp_atomic_fadd64(ep, add, remote_addr, rkey, result)
    ccall((:ucp_atomic_fadd64, libucp), ucs_status_t, (ucp_ep_h, UInt64, UInt64, ucp_rkey_h, Ptr{UInt64}), ep, add, remote_addr, rkey, result)
end

function ucp_atomic_swap32(ep, swap, remote_addr, rkey, result)
    ccall((:ucp_atomic_swap32, libucp), ucs_status_t, (ucp_ep_h, UInt32, UInt64, ucp_rkey_h, Ptr{UInt32}), ep, swap, remote_addr, rkey, result)
end

function ucp_atomic_swap64(ep, swap, remote_addr, rkey, result)
    ccall((:ucp_atomic_swap64, libucp), ucs_status_t, (ucp_ep_h, UInt64, UInt64, ucp_rkey_h, Ptr{UInt64}), ep, swap, remote_addr, rkey, result)
end

function ucp_atomic_cswap32(ep, compare, swap, remote_addr, rkey, result)
    ccall((:ucp_atomic_cswap32, libucp), ucs_status_t, (ucp_ep_h, UInt32, UInt32, UInt64, ucp_rkey_h, Ptr{UInt32}), ep, compare, swap, remote_addr, rkey, result)
end

function ucp_atomic_cswap64(ep, compare, swap, remote_addr, rkey, result)
    ccall((:ucp_atomic_cswap64, libucp), ucs_status_t, (ucp_ep_h, UInt64, UInt64, UInt64, ucp_rkey_h, Ptr{UInt64}), ep, compare, swap, remote_addr, rkey, result)
end

function ucp_ep_modify_nb(ep, params)
    ccall((:ucp_ep_modify_nb, libucp), ucs_status_ptr_t, (ucp_ep_h, Ptr{ucp_ep_params_t}), ep, params)
end
# Julia wrapper for header: /home/vchuravy/src/UCX.jl/deps/usr/include/ucp/api/ucp_def.h
# Automatically generated using Clang.jl wrap_c

# Julia wrapper for header: /home/vchuravy/src/UCX.jl/deps/usr/include/ucp/api/ucp_version.h
# Automatically generated using Clang.jl wrap_c

