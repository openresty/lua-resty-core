-- Copyright (C) Yichun Zhang (agentzh)


local base = require "resty.core.base"
base.allows_subsystem('http')


local ffi = require "ffi"
local os = require "os"
local C = ffi.C
local ffi_str = ffi.string
local getfenv = getfenv
local error = error


ffi.cdef[[

typedef struct ngx_cycle_s  ngx_cycle_t;

char *ngx_http_lua_ffi_os_getenv(ngx_cycle_t *cycle, ngx_http_request_t *r,
    const char *varname);
]]


local _M = { version = base.version }


function os.getenv(varname)
    local t = getfenv(0)

    local cycle = t.__ngx_cycle
    if not cycle then
        error("no cycle found")
    end

    local r = t.__ngx_req

    local value = C.ngx_http_lua_ffi_os_getenv(cycle, r, varname)
    if value == nil then
        return nil
    end

    return ffi_str(value)
end


return _M
