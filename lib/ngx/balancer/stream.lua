-- Copyright (C) Yichun Zhang (agentzh)


local ffi = require "ffi"
local base = require "resty.core.base"


local C = ffi.C
local ffi_str = ffi.string
local errmsg = base.get_errmsg_ptr()
local FFI_OK = base.FFI_OK
local FFI_ERROR = base.FFI_ERROR
local int_out = ffi.new("int[1]")
local getfenv = getfenv
local error = error
local type = type
local tonumber = tonumber


ffi.cdef[[
int ngx_stream_lua_ffi_balancer_set_current_peer(ngx_stream_session_t *s,
    const unsigned char *addr, size_t addr_len, int port, char **err);

int ngx_stream_lua_ffi_balancer_set_more_tries(ngx_stream_session_t *s,
    int count, char **err);

int ngx_stream_lua_ffi_balancer_get_last_failure(ngx_stream_session_t *s,
    int *status, char **err);

int ngx_stream_lua_ffi_balancer_set_timeouts(ngx_stream_session_t *s,
    long connect_timeout, long send_timeout,
    long read_timeout, char **err);
]]


local _M = { version = base.version }


function _M.set_current_peer(addr, port)
    local s = getfenv(0).__ngx_sess
    if not s then
        return error("no request found")
    end

    if not port then
        port = 0
    elseif type(port) ~= "number" then
        port = tonumber(port)
    end

    local rc = C.ngx_stream_lua_ffi_balancer_set_current_peer(s, addr, #addr,
                                                              port, errmsg)
    if rc == FFI_OK then
        return true
    end

    return nil, ffi_str(errmsg[0])
end


function _M.set_more_tries(count)
    local s = getfenv(0).__ngx_sess
    if not s then
        return error("no request found")
    end

    local rc = C.ngx_stream_lua_ffi_balancer_set_more_tries(s, count, errmsg)
    if rc == FFI_OK then
        if errmsg[0] == nil then
            return true
        end
        return true, ffi_str(errmsg[0])  -- return the warning
    end

    return nil, ffi_str(errmsg[0])
end


return _M
