-- Copyright (C) Yichun Zhang (agentzh)


local ffi = require 'ffi'
local base = require "resty.core.base"


local FFI_BAD_CONTEXT = base.FFI_BAD_CONTEXT
local new_tab = base.new_tab
local C = ffi.C
local ffi_cast = ffi.cast
local ffi_str = ffi.string
local get_string_buf = base.get_string_buf
local setmetatable = setmetatable
local gsub = ngx.re.gsub
local lower = string.lower
local rawget = rawget
local ngx = ngx
local getfenv = getfenv
local type = type


ffi.cdef[[
    typedef struct {
        ngx_http_lua_ffi_str_t   key;
        ngx_http_lua_ffi_str_t   value;
    } ngx_http_lua_ffi_table_elt_t;

    int ngx_http_lua_ffi_req_get_headers_count(ngx_http_request_t *r,
        int max);

    int ngx_http_lua_ffi_req_get_headers(ngx_http_request_t *r,
        ngx_http_lua_ffi_table_elt_t *out, int count, int raw);

    int ngx_http_lua_ffi_req_get_uri_args_count(ngx_http_request_t *r,
        int max);

    size_t ngx_http_lua_ffi_req_get_querystring_len(ngx_http_request_t *r);

    int ngx_http_lua_ffi_req_get_uri_args(ngx_http_request_t *r,
        unsigned char *buf, ngx_http_lua_ffi_table_elt_t *out, int count);
]]


local table_elt_type = ffi.typeof("ngx_http_lua_ffi_table_elt_t*")
local table_elt_size = ffi.sizeof("ngx_http_lua_ffi_table_elt_t")
local req_headers_mt = {
    __index = function (tb, key)
        return rawget(tb, (gsub(lower(key), '_', '-', "jo")))
    end
}


function ngx.req.get_headers(max_headers, raw)
    local r = getfenv(0).__ngx_req
    if not r then
        return error("no request found")
    end

    if not max_headers then
        max_headers = -1
    end

    if not raw then
        raw = 0
    else
        raw = 1
    end

    local n = C.ngx_http_lua_ffi_req_get_headers_count(r, max_headers)
    if n == FFI_BAD_CONTEXT then
        return error("API disabled in the current context")
    end

    if n == 0 then
        return {}
    end

    local raw_buf = get_string_buf(n * table_elt_size)
    local buf = ffi_cast(table_elt_type, raw_buf)

    local rc = C.ngx_http_lua_ffi_req_get_headers(r, buf, n, raw)
    if rc == 0 then
        local headers = new_tab(0, n)
        for i = 0, n - 1 do
            local h = buf[i]

            local key = h.key
            key = ffi_str(key.data, key.len)

            local value = h.value
            value = ffi_str(value.data, value.len)

            local existing = headers[key]
            if existing then
                if type(existing) == "table" then
                    existing[#existing + 1] = value
                else
                    headers[key] = {existing, value}
                end

            else
                headers[key] = value
            end
        end
        if raw == 0 then
            return setmetatable(headers, req_headers_mt)
        end
        return headers
    end

    return nil
end


function ngx.req.get_uri_args(max_args)
    local r = getfenv(0).__ngx_req
    if not r then
        return error("no request found")
    end

    if not max_args then
        max_args = -1
    end

    local n = C.ngx_http_lua_ffi_req_get_uri_args_count(r, max_args)
    if n == FFI_BAD_CONTEXT then
        return error("API disabled in the current context")
    end

    if n == 0 then
        return {}
    end

    local args_len = C.ngx_http_lua_ffi_req_get_querystring_len(r)

    local strbuf = get_string_buf(args_len + n * table_elt_size)
    local kvbuf = ffi_cast(table_elt_type, strbuf + args_len)

    local nargs = C.ngx_http_lua_ffi_req_get_uri_args(r, strbuf, kvbuf, n)

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
