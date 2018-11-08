-- Copyright (C) Yichun Zhang (agentzh)


local base = require "resty.core.base"
base.allows_subsystem('http')


local ffi = require 'ffi'
local errmsg = base.get_errmsg_ptr()
local FFI_ERROR = base.FFI_ERROR
local ffi_str = ffi.string
local ngx_phase = ngx.get_phase
local tonumber = tonumber


local process_type_names = {
    [0 ]  = "single",
    [1 ]  = "master",
    [2 ]  = "signaller",
    [3 ]  = "worker",
    [4 ]  = "helper",
    [99]  = "privileged agent",
}


local C = ffi.C
local _M = { version = base.version }


ffi.cdef[[
int ngx_http_lua_ffi_enable_privileged_agent(char **err);
int ngx_http_lua_ffi_get_process_type(void);
void ngx_http_lua_ffi_process_signal_graceful_exit(void);
int ngx_http_lua_ffi_master_pid(void);
]]


function _M.type()
    local typ = C.ngx_http_lua_ffi_get_process_type()
    return process_type_names[tonumber(typ)]
end


function _M.enable_privileged_agent()
    if ngx_phase() ~= "init" then
        return nil, "API disabled in the current context"
    end

    local rc = C.ngx_http_lua_ffi_enable_privileged_agent(errmsg)

    if rc == FFI_ERROR then
        return nil, ffi_str(errmsg[0])
    end

    return true
end


function _M.signal_graceful_exit()
    C.ngx_http_lua_ffi_process_signal_graceful_exit()
end


function _M.get_master_pid()
    local pid = C.ngx_http_lua_ffi_master_pid()
    if pid == FFI_ERROR then
        return nil
    end

    return tonumber(pid)
end


return _M
