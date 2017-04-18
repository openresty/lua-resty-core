-- Copyright (C) Yichun Zhang (agentzh)


local ffi = require 'ffi'
local base = require "resty.core.base"
local getfenv = getfenv

local process_types = {
    [base.FFI_PROCESS_SINGLE    ]  = "single process",
    [base.FFI_PROCESS_MASTER    ]  = "master process",
    [base.FFI_PROCESS_SIGNALLER ]  = "signaller process",
    [base.FFI_PROCESS_WORKER    ]  = "worker process",
    [base.FFI_PROCESS_HELPER    ]  = "helper process",
    [base.FFI_PROCESS_PRIVILEGED]  = "privileged agent process",
}


local C = ffi.C
local _M = { version = base.version }


ffi.cdef[[
void ngx_http_lua_ffi_privileged_agent(int enable);
int ngx_http_lua_ffi_process_type(void);
]]


function _M.type()
    return C.ngx_http_lua_ffi_process_type()
end


function _M.type_name(typ)
    return process_types[typ]
end


function _M.privileged_agent(enable)
    local r = getfenv(0).__ngx_req
    if r ~= nil then
        error("API disabled in the current context")
    end

    C.ngx_http_lua_ffi_privileged_agent(enable)
    return true
end


return _M
