-- Copyright (C) 2013 Yichun Zhang (agentzh)


local ffi = require 'ffi'
local base = require "resty.core.base"


local C = ffi.C
local ffi_new = ffi.new
local ffi_cast = ffi.cast
local ffi_str = ffi.string
local FFI_BAD_CONTEXT = base.FFI_BAD_CONTEXT
local FFI_NO_REQ_CTX = base.FFI_NO_REQ_CTX
local FFI_ERROR = base.FFI_ERROR
local FFI_DECLINED = base.FFI_DECLINED
local get_string_buf = base.get_string_buf
local getmetatable = getmetatable
local type = type
local tostring = tostring
local getfenv = getfenv
local error = error
local ngx = ngx


local errmsg = base.get_errmsg_ptr()
local ngx_str_type = ffi.typeof("ngx_str_t *")
local ngx_str_size = ffi.sizeof("ngx_str_t")


ffi.cdef[[
    int ngx_http_lua_ffi_set_resp_header(ngx_http_request_t *r,
        const char *key_data, size_t key_len, int is_nil,
        const char *sval, size_t sval_len, ngx_str_t *mvals,
        size_t mvals_len, char **errmsg);
]]


local function set_resp_header(tb, key, value)
    local r = getfenv(0).__ngx_req
    if not r then
        return error("no request found")
    end

    if type(key) ~= "string" then
        key = tostring(key)
    end

    local rc
    if value == nil then
        rc = C.ngx_http_lua_ffi_set_resp_header(r, key, #key, true, nil, 0,
                                                nil, 0, errmsg)
    else
        local sval, sval_len, mvals, mvals_len

        if type(value) == "table" then
            mvals_len = #value
            mvals = ffi_cast(ngx_str_type,
                             get_string_buf(ngx_str_size * mvals_len))
            for i = 1, mvals_len do
                local s = value[i]
                if type(s) ~= "string" then
                    s = tostring(s)
                end
                local str = mvals[i - 1]
                str.data = s
                str.len = #s
            end

            sval_len = 0

        else
            if type(value) ~= "string" then
                sval = tostring(value)
            else
                sval = value
            end
            sval_len = #sval

            mvals_len = 0
        end

        rc = C.ngx_http_lua_ffi_set_resp_header(r, key, #key, false, sval,
                                                sval_len, mvals, mvals_len,
                                                errmsg)
    end

    if rc == 0 or rc == FFI_DECLINED then
        return
    end

    if rc == FFI_NO_REQ_CTX then
        return error("no request ctx found")
    end

    if rc == FFI_BAD_CONTEXT then
        return error("API disabled in the current context")
    end

    -- rc == FFI_ERROR
    return error(ffi_str(errmsg[0]))
end


getmetatable(ngx.header).__newindex = set_resp_header


return {
    version = base.version
}
