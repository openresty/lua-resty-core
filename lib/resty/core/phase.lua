local ffi = require 'ffi'
local C = ffi.C
local base = require "resty.core.base"
local FFI_ERROR = base.FFI_ERROR
local tostring = tostring

ffi.cdef[[
int ngx_http_lua_ffi_get_phase(ngx_http_request_t *r, char **err)
]]


local _M = {
    _VERSION = base.version
}

local errmsg = base.get_errmsg_ptr()
local context_lookup = {}
context_lookup[0x0001] = "set"
context_lookup[0x0002] = "rewrite"
context_lookup[0x0004] = "access"
context_lookup[0x0008] = "content"
context_lookup[0x0010] = "log"
context_lookup[0x0020] = "header_filter"
context_lookup[0x0040] = "body_filter"
context_lookup[0x0080] = "timer"
context_lookup[0x0100] = "init_worker"
context_lookup[0x0200] = "balancer"
context_lookup[0x0400] = "ssl_cert"
context_lookup[0x0800] = "ssl_session_store"
context_lookup[0x1000] = "ssl_session_fetch"


function ngx.get_phase()
    local r = getfenv(0).__ngx_req

    -- if we have no request object, assume we are called from the "init" phase
    if not r then
        return "init"
    end

    local context = C.ngx_http_lua_ffi_get_phase(r, errmsg)
    if context == FFI_ERROR then -- NGX_ERROR
        error(errmsg)
    end

    local phase = context_lookup[context]
    if not phase then
        error("unknown phase: " .. tostring(context))
    end

    return phase
end


return _M
