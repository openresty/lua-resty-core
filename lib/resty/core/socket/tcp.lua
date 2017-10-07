-- Copyright (C) Yichun Zhang (agentzh)


local ffi = require "ffi"
local debug = require 'debug'
local base = require "resty.core.base"


local C = ffi.C
local ffi_str = ffi.string
local registry = debug.getregistry()
local error = error
local errmsg = base.get_errmsg_ptr()
local FFI_OK = base.FFI_OK


ffi.cdef[[

int ngx_http_lua_ffi_socket_tcp_setsslctx(ngx_http_request_t *r, void *u,
    void *cdata_ctx, char **err);

]]


local function check_tcp(tcp)
    if not tcp or type(tcp) ~= "table" then
        return error("bad \"tcp\" argument")
    end

    tcp = tcp[1]
    if type(tcp) ~= "userdata" then
        return error("bad \"tcp\" argument")
    end

    return tcp
end


local function setsslctx(tcp, ssl_ctx)
    tcp = check_tcp(tcp)

    local r = getfenv(0).__ngx_req
    if not r then
        return error("no request found")
    end

    local rc = C.ngx_http_lua_ffi_socket_tcp_setsslctx(r, tcp, ssl_ctx, errmsg)
    if rc ~= FFI_OK then
        return nil, ffi_str(errmsg[0])
    end

    return true
end


local mt = registry.__ngx_socket_tcp_mt
if mt then
    mt = mt.__index
    if mt then
        mt.setsslctx = setsslctx
    end
end


return {
    version = base.version
}
