-- Copyright (C) 2013 Yichun Zhang (agentzh)


local ffi = require 'ffi'
local ffi_string = ffi.string
local ffi_new = ffi.new
local C = ffi.C
local strlen = string.len
local setmetatable = setmetatable
local ngx = ngx
local type = type
local tostring = tostring
local error = error
-- local print = print
-- local tonumber = tonumber


module(...)


ffi.cdef[[
    size_t ngx_http_lua_ffi_uri_escaped_length(const unsigned char *src,
                                               size_t len);

    void ngx_http_lua_ffi_escape_uri(const unsigned char *src, size_t len,
                                     unsigned char *dst);

    size_t ngx_http_lua_ffi_unescape_uri(const unsigned char *src,
                                         size_t len, unsigned char *dst);
]]



_VERSION = '0.0.1'


ngx.escape_uri = function (s)
    if type(s) ~= 'string' then
        if not s then
            s = ''
        else
            s = tostring(s)
        end
    end
    local slen = strlen(s)
    local dlen = C.ngx_http_lua_ffi_uri_escaped_length(s, slen)
    -- print("dlen: ", tonumber(dlen))
    if dlen == slen then
        return s
    end
    local dst = ffi_new("unsigned char[?]", dlen)
    C.ngx_http_lua_ffi_escape_uri(s, slen, dst)
    return ffi_string(dst, dlen)
end


ngx.unescape_uri = function (s)
    if type(s) ~= 'string' then
        if not s then
            s = ''
        else
            s = tostring(s)
        end
    end
    local slen = strlen(s)
    local dlen = slen
    local dst = ffi_new("unsigned char[?]", dlen)
    dlen = C.ngx_http_lua_ffi_unescape_uri(s, slen, dst)
    return ffi_string(dst, dlen)
end


local class_mt = {
    -- to prevent use of casual module global variables
    __newindex = function (table, key, val)
        error('attempt to write to undeclared variable "' .. key .. '"')
    end
}

setmetatable(_M, class_mt)
