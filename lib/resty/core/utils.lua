-- Copyright (C) Yichun Zhang (agentzh)


local ffi = require "ffi"
local base = require "resty.core.base"
base.allows_subsystem("http")


local C = ffi.C
local ffi_str = ffi.string
local ffi_copy = ffi.copy
local byte = string.byte
local str_find = string.find
local get_string_buf = base.get_string_buf


ffi.cdef[[
    void ngx_http_lua_ffi_str_replace_char(unsigned char *buf, size_t len,
        const unsigned char find, const unsigned char replace);
]]


local _M = {
    version = base.version
}


function _M.str_replace_char(str, find, replace)
    if not str_find(str, find, nil, true) then
        return str
    end

    local len = #str
    local buf = get_string_buf(len)
    ffi_copy(buf, str)

    C.ngx_http_lua_ffi_str_replace_char(buf, len, byte(find),
                                        byte(replace))

    return ffi_str(buf, len)
end


return _M
