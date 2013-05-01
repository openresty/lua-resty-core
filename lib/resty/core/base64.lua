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


module(...)


ffi.cdef[[
    size_t ngx_http_lua_ffi_encode_base64(const unsigned char *src,
                                          size_t len, unsigned char *dst);

    int ngx_http_lua_ffi_decode_base64(const unsigned char *src,
                                       size_t len, unsigned char *dst,
                                       size_t *dlen);
]]



_VERSION = '0.0.1'


local function base64_encoded_length(len)
    return ((len + 2) / 3) * 4
end


ngx.encode_base64 = function (s)
    if type(s) ~= 'string' then
        if not s then
            s = ''
        else
            s = tostring(s)
        end
    end
    local slen = strlen(s)
    local dlen = base64_encoded_length(slen)
    local dst = ffi_new("unsigned char[?]", dlen)
    dlen = C.ngx_http_lua_ffi_encode_base64(s, slen, dst)
    return ffi_string(dst, dlen)
end


local function base64_decoded_length(len)
    return ((len + 3) / 4) * 3
end


ngx.decode_base64 = function (s)
    if type(s) ~= 'string' then
        if not s then
            s = ''
        else
            s = tostring(s)
        end
    end
    local slen = strlen(s)
    local dlen = base64_decoded_length(slen)
    local dst = ffi_new("unsigned char[?]", dlen)
    local pdlen = ffi_new("size_t[1]")
    local ok = C.ngx_http_lua_ffi_decode_base64(s, slen, dst, pdlen)
    if ok == 0 then
        return nil
    end
    return ffi_string(dst, pdlen[0])
end


local class_mt = {
    -- to prevent use of casual module global variables
    __newindex = function (table, key, val)
        error('attempt to write to undeclared variable "' .. key .. '"')
    end
}

setmetatable(_M, class_mt)
