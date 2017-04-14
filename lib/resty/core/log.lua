-- Copyright (C) OpenResty Inc.


local ffi = require 'ffi'
local ffi_string = ffi.string
local ngx = ngx
local base = require "resty.core.base"
local get_string_buf = base.get_string_buf
local get_size_ptr = base.get_size_ptr
local C = ffi.C
local ffi_cast = ffi.cast
local new_tab = base.new_tab


ffi.cdef[[
    typedef struct {
        ngx_http_lua_ffi_str_t   key;
        ngx_http_lua_ffi_str_t   value;
    } ngx_http_lua_ffi_table_elt_t;

    int ngx_http_lua_ffi_filter_log(int level, unsigned char *err,
        size_t *errlen);
    int ngx_http_lua_ffi_errlog_count(unsigned char *err, size_t *errlen);
    int ngx_http_lua_ffi_errlog(ngx_http_lua_ffi_table_elt_t *out,
        unsigned char *err, size_t *errlen);
]]


local table_elt_type = ffi.typeof("ngx_http_lua_ffi_table_elt_t*")
local table_elt_size = ffi.sizeof("ngx_http_lua_ffi_table_elt_t")

local ERR_BUF_SIZE = 128
local FFI_ERROR = base.FFI_ERROR


function ngx.filter_log(level)
    local err = get_string_buf(ERR_BUF_SIZE)
    local errlen = get_size_ptr()
    errlen[0] = ERR_BUF_SIZE
    local rc = C.ngx_http_lua_ffi_filter_log(level, err, errlen)

    if rc == FFI_ERROR then
        return error(ffi_string(err, errlen[0]))
    end
end


function ngx.errlog()
    local err = get_string_buf(ERR_BUF_SIZE)
    local errlen = get_size_ptr()
    errlen[0] = ERR_BUF_SIZE
    local n = C.ngx_http_lua_ffi_errlog_count(err, errlen)

    if n == FFI_ERROR then
        return error(ffi_string(err, errlen[0]))
    end

    if n == 0 then
        return {}
    end

    local raw_buf = get_string_buf(n * table_elt_size)
    local buf = ffi_cast(table_elt_type, raw_buf)

    local rc = C.ngx_http_lua_ffi_errlog(buf, err, errlen)
    if rc == FFI_ERROR then
        return error(ffi_string(err, errlen[0]))
    end

    local logs = new_tab(n, 0)
    for i = 1, n do
        local log = new_tab(2, 0)
        local k = buf[i - 1].key
        local v = buf[i - 1].value

        log[1] = k.len
        log[2] = ffi_string(v.data, v.len)
        logs[i] = log
    end

    return logs;
end


return {
    _VERSION = base.version
}
