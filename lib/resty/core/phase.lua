local ffi = require 'ffi'
local C = ffi.C
local base = require "resty.core.base"
local tostring = tostring

ffi.cdef[[
int ngx_http_lua_ffi_get_phase(ngx_http_request_t *r, char **err)
]]


local _M = {
    _VERSION = base.version
}


local errmsg = base.get_errmsg_ptr()
local context_lookup = {
    ["1"] = "set",
    ["2"] = "rewrite",
    ["4"] = "access",
    ["8"] = "content",
    ["16"] = "log",
    ["32"] = "header_filter",
    ["64"] = "body_filter",
    ["128"] = "timer",
    ["256"] = "init_worker",
    ["512"] = "balancer",
    ["1024"] = "ssl_cert",
    ["2048"] = "ssl_session_store",
    ["4096"] = "ssl_session_fetch",
}


function ngx.get_phase()
    local r = getfenv(0).__ngx_req

    -- If we have no request object, assume we are called from the "init" phase
    if not r then
        return "init"
    end

    local context = C.ngx_http_lua_ffi_get_phase(r, errmsg)
    if context == -1 then -- NGX_ERROR
        error(errmsg)
    end

    local ctx_str = tostring(context)
    local phase = context_lookup[ctx_str]
    if not phase then
        error("unknown phase: " .. ctx_str)
    end

    return phase
end


return _M
