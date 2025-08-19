-- Copyright (C) Yichun Zhang (agentzh)
--
-- Author: Thibault Charbonnier (thibaultcha)


local base = require "resty.core.base"
base.allows_subsystem("http")


local ffi = require "ffi"
local C = ffi.C
--local FFI_OK = base.FFI_OK
local FFI_ERROR = base.FFI_ERROR
local FFI_DECLINED = base.FFI_DECLINED
local ffi_str = ffi.string
local get_string_buf = base.get_string_buf
local get_size_ptr = base.get_size_ptr
local find = string.find
local type = type


local ERR_BUF_SIZE = 128


ffi.cdef [[
    unsigned int ngx_http_lua_ffi_is_configure_phase();

    int ngx_http_lua_ffi_configure_shared_dict(ngx_str_t *name,
        ngx_str_t *size, unsigned char *errstr, size_t *errlen);

    void ngx_http_lua_ffi_configure_max_pending_timers(int n_timers);

    void ngx_http_lua_ffi_configure_max_running_timers(int n_timers);

    int ngx_http_lua_ffi_configure_env(const unsigned char *value,
                                       size_t name_len, size_t len);
]]


local _M = { version = base.version }


function _M.is_configure_phase()
    return C.ngx_http_lua_ffi_is_configure_phase() == 1
end


do
    local name_str_t = ffi.new("ngx_str_t[1]")
    local size_str_t = ffi.new("ngx_str_t[1]")


    function _M.shared_dict(name, size)
        if not _M.is_configure_phase() then
            error("API disabled in the current context", 2)
        end

        if type(name) ~= "string" then
            error("name must be a string", 2)
        end

        if type(size) ~= "string" then
            error("size must be a string", 2)
        end

        local name_len = #name
        if name_len == 0 then
            error("invalid lua shared dict name", 2)
        end

        local size_len = #size
        if size_len == 0 then
            error("invalid lua shared dict size", 2)
        end

        local name_t = name_str_t[0]
        local size_t = size_str_t[0]

        name_t.data = name
        name_t.len = name_len

        size_t.data = size
        size_t.len = size_len

        local err = get_string_buf(ERR_BUF_SIZE)
        local errlen = get_size_ptr()
        errlen[0] = ERR_BUF_SIZE

        local rc = C.ngx_http_lua_ffi_configure_shared_dict(name_str_t,
                                                            size_str_t, err,
                                                            errlen)
        if rc == FFI_DECLINED then
            error(ffi_str(err, errlen[0]), 2)
        end

        if rc == FFI_ERROR then
            error("no memory")
        end

        -- NGINX_OK/FFI_OK
    end
end


function _M.max_pending_timers(n_timers)
    if not _M.is_configure_phase() then
        error("API disabled in the current context", 2)
    end

    if type(n_timers) ~= "number" then
        error("n_timers must be a number", 2)
    end

    if n_timers < 0 then
        error("n_timers must be positive", 2)
    end

    C.ngx_http_lua_ffi_configure_max_pending_timers(n_timers)
end


function _M.max_running_timers(n_timers)
    if not _M.is_configure_phase() then
        error("API disabled in the current context", 2)
    end

    if type(n_timers) ~= "number" then
        error("n_timers must be a number", 2)
    end

    if n_timers < 0 then
        error("n_timers must be positive", 2)
    end

    C.ngx_http_lua_ffi_configure_max_running_timers(n_timers)
end


function _M.env(value)
    if not _M.is_configure_phase() then
        error("API disabled in the current context", 2)
    end

    if type(value) ~= "string" then
        error("value must be a string", 2)
    end

    local len = #value
    local idx = find(value, "=")

    local rc = C.ngx_http_lua_ffi_configure_env(value, idx and idx - 1 or len,
                                                len)
    if rc == FFI_ERROR then
        error("no memory")
    end
end


return _M
