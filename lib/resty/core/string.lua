-- Copyright (C) Yichun Zhang (agentzh)


local ffi = require 'ffi'
local base = require "resty.core.base"


local new_tab = base.new_tab
local C = ffi.C
local ffi_cast = ffi.cast
local ffi_str = ffi.string
local get_string_buf = base.get_string_buf
local ngx = ngx
local type = type
local tonumber = tonumber


ffi.cdef[[
    typedef struct {
        ngx_http_lua_ffi_str_t   key;
        ngx_http_lua_ffi_str_t   value;
    } ngx_http_lua_ffi_table_elt_t;

    int ngx_http_lua_ffi_get_args_count(const char *args,
        size_t buf_len, int max);

    int ngx_http_lua_ffi_decode_args(char *buf, const char *args,
        size_t len, ngx_http_lua_ffi_table_elt_t *out, int count);
]]


local table_elt_type = ffi.typeof("ngx_http_lua_ffi_table_elt_t*")
local table_elt_size = ffi.sizeof("ngx_http_lua_ffi_table_elt_t")


function ngx.decode_args(str, max_args)
    max_args = tonumber(max_args)
    if not max_args or max_args < 0 then
        max_args = -1
    end

    local args_len = #str

    local n = C.ngx_http_lua_ffi_get_args_count(str, args_len, max_args)
    if n == 0 then
        return {}
    end

    local strbuf = get_string_buf(args_len + n * table_elt_size)
    local kvbuf = ffi_cast(table_elt_type, strbuf + args_len)

    local nargs = C.ngx_http_lua_ffi_decode_args(strbuf, str,
                                                 args_len, kvbuf, n)

    local args = new_tab(0, nargs)
    for i = 0, nargs - 1 do
        local arg = kvbuf[i]

        local key = arg.key
        key = ffi_str(key.data, key.len)

        local value = arg.value
        local len = value.len
        if len == -1 then
            value = true
        else
            value = ffi_str(value.data, len)
        end

        local existing = args[key]
        if existing then
            if type(existing) == "table" then
                existing[#existing + 1] = value
            else
                args[key] = {existing, value}
            end

        else
            args[key] = value
        end
    end

    return args
end


return {
    version = base.version
}
