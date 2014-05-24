-- Copyright (C) Yichun Zhang (agentzh)


local ffi = require 'ffi'
local base = require "resty.core.base"


local tonumber = tonumber
local C = ffi.C


ffi.cdef[[
double ngx_http_lua_ffi_ngx_now(void);
int ngx_http_lua_ffi_time(void);
]]


function ngx.now()
    return tonumber(C.ngx_http_lua_ffi_ngx_now())
end


function ngx.time()
    return tonumber(C.ngx_http_lua_ffi_time())
end


return {
    version = base.version
}
