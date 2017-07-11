-- Copyright (C) Yichun Zhang (agentzh)


local ffi = require 'ffi'
local base = require "resty.core.base"


local FFI_BAD_CONTEXT = base.FFI_BAD_CONTEXT
local C = ffi.C
local ffi_str = ffi.string
local get_size_ptr = base.get_size_ptr
local getfenv = getfenv
local error = error
local tonumber = tonumber


local DEFAULT_EXT_MAXSIZE = 255


local _M = { version = base.version }


local charpp = ffi.new("char*[1]")


ffi.cdef[[
    int ngx_http_lua_ffi_req_get_uri_ext(ngx_http_request_t *r, char **buf,
        size_t *len);
]]


function _M.get_uri_ext(ext_len)
    local r = getfenv(0).__ngx_req
    if not r then
        return error("no request found")
    end

    ext_len = tonumber(ext_len) or DEFAULT_EXT_MAXSIZE
    if ext_len <= 0 then
        ext_len = DEFAULT_EXT_MAXSIZE
    end

    local sizep = get_size_ptr()
    sizep[0] = ext_len

    local rc = C.ngx_http_lua_ffi_req_get_uri_ext(r, charpp, sizep)
    if rc == FFI_BAD_CONTEXT then
        return error("API disabled in the current context")
    end

    return ffi_str(charpp[0], sizep[0])
end


return _M
