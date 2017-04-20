-- Copyright (C) Yichun Zhang (agentzh)


local ffi = require 'ffi'
local base = require "resty.core.base"
local getfenv = getfenv

local process_types = {
    [base.FFI_PROCESS_SINGLE    ]  = "single",
    [base.FFI_PROCESS_MASTER    ]  = "master",
    [base.FFI_PROCESS_SIGNALLER ]  = "signaller",
    [base.FFI_PROCESS_WORKER    ]  = "worker",
    [base.FFI_PROCESS_HELPER    ]  = "helper",
    [base.FFI_PROCESS_PRIVILEGED]  = "privileged agent",
}


local C = ffi.C
local _M = { version = base.version }


ffi.cdef[[
int ngx_http_lua_ffi_enable_privileged_agent(void);
int ngx_http_lua_ffi_get_process_type(void);
]]


function _M.type(is_str_name)
    local typ = C.ngx_http_lua_ffi_get_process_type()
    if is_str_name then
        return process_types[typ]
    end
    return typ
end


function _M.enable_privileged_agent()
    local r = getfenv(0).__ngx_req
    if r ~= nil then
        return nil, "API disabled in the current context"
    end

    return C.ngx_http_lua_ffi_enable_privileged_agent()
end


return _M
