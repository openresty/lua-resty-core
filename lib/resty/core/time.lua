-- Copyright (C) Yichun Zhang (agentzh)


local ffi = require 'ffi'
local base = require "resty.core.base"


local error = error
local tonumber = tonumber
local type = type
local C = ffi.C
local ffi_str = ffi.string
local get_size_ptr = base.get_size_ptr
local get_string_buf = base.get_string_buf
local ngx = ngx
local subsystem = ngx.config.subsystem
local FFI_ERROR = ngx.ERROR


ffi.cdef[[
double ngx_http_lua_ffi_now(void);
long ngx_http_lua_ffi_time(void);
void ngx_http_lua_ffi_today(unsigned char *buf);
void ngx_http_lua_ffi_localtime(unsigned char *buf);
void ngx_http_lua_ffi_utctime(unsigned char *buf);
void ngx_http_lua_ffi_update_time(void);
int ngx_http_lua_ffi_cookie_time(unsigned char *buf, long t);
void ngx_http_lua_ffi_http_time(unsigned char *buf, long t);
void ngx_http_lua_ffi_parse_http_time(const unsigned char *str, size_t len,
    size_t *t);
]]


function ngx.now()
    return tonumber(C.ngx_http_lua_ffi_now())
end


function ngx.time()
    return tonumber(C.ngx_http_lua_ffi_time())
end


function ngx.update_time()
    C.ngx_http_lua_ffi_update_time()
end


function ngx.today()
    -- the format of today is 2010-11-19
    local today_buf_size = 10
    local buf = get_string_buf(today_buf_size)
    C.ngx_http_lua_ffi_today(buf)
    return ffi_str(buf, today_buf_size)
end


function ngx.localtime()
    -- the format of localtime is 2010-11-19 20:56:31
    local localtime_buf_size = 19
    local buf = get_string_buf(localtime_buf_size)
    C.ngx_http_lua_ffi_localtime(buf)
    return ffi_str(buf, localtime_buf_size)
end


function ngx.utctime()
    -- the format of utctime is 2010-11-19 20:56:31
    local utctime_buf_size = 19
    local buf = get_string_buf(utctime_buf_size)
    C.ngx_http_lua_ffi_utctime(buf)
    return ffi_str(buf, utctime_buf_size)
end


if subsystem == 'http' then
    function ngx.cookie_time(sec)
        if type(sec) ~= "number" then
            return error("number argument only")
        end

        -- the format of cookie time is Mon, 28-Sep-2038 06:00:00 GMT
        -- or Mon, 28-Sep-18 06:00:00 GMT
        local cookie_time_buf_size = 29
        local buf = get_string_buf(cookie_time_buf_size)
        local used_size = C.ngx_http_lua_ffi_cookie_time(buf, sec)
        return ffi_str(buf, used_size)
    end


    function ngx.http_time(sec)
        if type(sec) ~= "number" then
            return error("number argument only")
        end

        -- the format of http time is Mon, 28 Sep 1970 06:00:00 GMT
        local http_time_buf_size = 29
        local buf = get_string_buf(http_time_buf_size)
        C.ngx_http_lua_ffi_http_time(buf, sec)
        return ffi_str(buf, http_time_buf_size)
    end


    function ngx.parse_http_time(time_str)
        if type(time_str) ~= "string" then
            return error("string argument only")
        end

        local out_val = get_size_ptr()
        C.ngx_http_lua_ffi_parse_http_time(time_str, #time_str, out_val)

        local res = out_val[0]
        if res == FFI_ERROR then
            return nil
        end

        return tonumber(res)
    end
end  -- if subsystem == 'http' then


return {
    version = base.version
}
