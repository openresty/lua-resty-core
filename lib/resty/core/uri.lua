-- Copyright (C) Yichun Zhang (agentzh)


local ffi = require "ffi"
local base = require "resty.core.base"


local C = ffi.C
local ffi_string = ffi.string
local ngx = ngx
local type = type
local tostring = tostring
local get_string_buf = base.get_string_buf
local subsystem = ngx.config.subsystem


local ngx_lua_ffi_escape_uri
local ngx_lua_ffi_unescape_uri
local ngx_lua_ffi_uri_escaped_length


if subsystem == "http" then
    ffi.cdef[[
    size_t ngx_http_lua_ffi_uri_escaped_length(const unsigned char *src,
                                               size_t len);

    void ngx_http_lua_ffi_escape_uri(const unsigned char *src, size_t len,
                                     unsigned char *dst);

    size_t ngx_http_lua_ffi_unescape_uri(const unsigned char *src,
                                         size_t len, unsigned char *dst);
    ]]

    ngx_lua_ffi_escape_uri = C.ngx_http_lua_ffi_escape_uri
    ngx_lua_ffi_unescape_uri = C.ngx_http_lua_ffi_unescape_uri
    ngx_lua_ffi_uri_escaped_length = C.ngx_http_lua_ffi_uri_escaped_length

elseif subsystem == "stream" then
    ffi.cdef[[
    size_t ngx_stream_lua_ffi_uri_escaped_length(const unsigned char *src,
                                                 size_t len);

    void ngx_stream_lua_ffi_escape_uri(const unsigned char *src, size_t len,
                                       unsigned char *dst);

    size_t ngx_stream_lua_ffi_unescape_uri(const unsigned char *src,
                                           size_t len, unsigned char *dst);
    ]]

    ngx_lua_ffi_escape_uri = C.ngx_stream_lua_ffi_escape_uri
    ngx_lua_ffi_unescape_uri = C.ngx_stream_lua_ffi_unescape_uri
    ngx_lua_ffi_uri_escaped_length = C.ngx_stream_lua_ffi_uri_escaped_length
end


ngx.escape_uri = function (s)
    if type(s) ~= 'string' then
        if not s then
            s = ''
        else
            s = tostring(s)
        end
    end
    local slen = #s
    local dlen = ngx_lua_ffi_uri_escaped_length(s, slen)
    -- print("dlen: ", tonumber(dlen))
    if dlen == slen then
        return s
    end
    local dst = get_string_buf(dlen)
    ngx_lua_ffi_escape_uri(s, slen, dst)
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
    local slen = #s
    local dlen = slen
    local dst = get_string_buf(dlen)
    dlen = ngx_lua_ffi_unescape_uri(s, slen, dst)
    return ffi_string(dst, dlen)
end


return {
    version = base.version,
}
