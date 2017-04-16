-- Copyright (C) Yichun Zhang (agentzh)


local ffi = require 'ffi'
local base = require "resty.core.base"
local getfenv = getfenv
local new_tab = base.new_tab


local C = ffi.C
ngx.process = new_tab(0, 2)


ffi.cdef[[
void ngx_http_lua_ffi_worker_priveleged(int enable);
int ngx_http_lua_ffi_worker_type(void);
]]


function ngx.process.type()
    return C.ngx_http_lua_ffi_worker_type()
end


function ngx.process.privelege(enable)
    local r = getfenv(0).__ngx_req
    if r ~= nil then
        error("API disabled in the current context")
    end

    C.ngx_http_lua_ffi_worker_priveleged(enable)
    return true
end


return {
    _VERSION = base.version
}
