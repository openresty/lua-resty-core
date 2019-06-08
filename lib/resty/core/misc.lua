-- Copyright (C) Yichun Zhang (agentzh)


local base = require "resty.core.base"
local ffi = require "ffi"
local os = require "os"


local FFI_OK = base.FFI_OK
local FFI_NO_REQ_CTX = base.FFI_NO_REQ_CTX
local FFI_BAD_CONTEXT = base.FFI_BAD_CONTEXT
local get_string_buf = base.get_string_buf
local get_string_buf_size = base.get_string_buf_size
local get_size_ptr = base.get_size_ptr
local new_tab = base.new_tab
local C = ffi.C
local ffi_new = ffi.new
local ffi_str = ffi.string
local getmetatable = getmetatable
local ngx = ngx
local get_request = base.get_request
local type = type
local error = error
local tonumber = tonumber
local subsystem = ngx.config.subsystem


local _M
local ngx_lua_ffi_get_conf_env


if subsystem == 'http' then
    _M = new_tab(0, 3)


    local ngx_magic_key_getters = new_tab(0, 4)
    local ngx_magic_key_setters = new_tab(0, 2)


    local function register_getter(key, func)
        ngx_magic_key_getters[key] = func
    end
    _M.register_ngx_magic_key_getter = register_getter


    local function register_setter(key, func)
        ngx_magic_key_setters[key] = func
    end
    _M.register_ngx_magic_key_setter = register_setter


    local mt = getmetatable(ngx)


    local old_index = mt.__index
    mt.__index = function (tb, key)
        local f = ngx_magic_key_getters[key]
        if f then
            return f()
        end
        return old_index(tb, key)
    end


    local old_newindex = mt.__newindex
    mt.__newindex = function (tb, key, ctx)
        local f = ngx_magic_key_setters[key]
        if f then
            return f(ctx)
        end
        return old_newindex(tb, key, ctx)
    end


    ffi.cdef[[
int ngx_http_lua_ffi_get_resp_status(ngx_http_request_t *r);
int ngx_http_lua_ffi_set_resp_status(ngx_http_request_t *r, int r);
int ngx_http_lua_ffi_is_subrequest(ngx_http_request_t *r);
int ngx_http_lua_ffi_headers_sent(ngx_http_request_t *r);
int ngx_http_lua_ffi_get_conf_env(const unsigned char *name,
    unsigned char **env_buf, size_t *name_len);
    ]]


    ngx_lua_ffi_get_conf_env = C.ngx_http_lua_ffi_get_conf_env


    -- ngx.status

    local function get_status()
        local r = get_request()

        if not r then
            error("no request found")
        end

        local rc = C.ngx_http_lua_ffi_get_resp_status(r)

        if rc == FFI_BAD_CONTEXT then
            error("API disabled in the current context", 2)
        end

        return rc
    end
    register_getter("status", get_status)


    local function set_status(status)
        local r = get_request()

        if not r then
            error("no request found")
        end

        if type(status) ~= 'number' then
            status = tonumber(status)
        end

        local rc = C.ngx_http_lua_ffi_set_resp_status(r, status)

        if rc == FFI_BAD_CONTEXT then
            error("API disabled in the current context", 2)
        end

        return
    end
    register_setter("status", set_status)


    -- ngx.is_subrequest

    local function is_subreq()
        local r = get_request()

        if not r then
            error("no request found")
        end

        local rc = C.ngx_http_lua_ffi_is_subrequest(r)

        if rc == FFI_BAD_CONTEXT then
            error("API disabled in the current context", 2)
        end

        return rc == 1
    end
    register_getter("is_subrequest", is_subreq)


    -- ngx.headers_sent

    local function headers_sent()
        local r = get_request()

        if not r then
            error("no request found")
        end

        local rc = C.ngx_http_lua_ffi_headers_sent(r)

        if rc == FFI_NO_REQ_CTX then
            error("no request ctx found")
        end

        if rc == FFI_BAD_CONTEXT then
            error("API disabled in the current context", 2)
        end

        return rc == 1
    end
    register_getter("headers_sent", headers_sent)

elseif subsystem == 'stream' then
    _M = new_tab(0, 1)


    ffi.cdef[[
int ngx_stream_lua_ffi_get_conf_env(const unsigned char *name,
    unsigned char **env_buf, size_t *name_len);
    ]]


    ngx_lua_ffi_get_conf_env = C.ngx_stream_lua_ffi_get_conf_env
end


do
    local _getenv = os.getenv
    local env_ptr = ffi_new("unsigned char *[1]")

    os.getenv = function (name)
        local r = get_request()
        if r then
            -- past init_by_lua* phase now
            os.getenv = _getenv
            env_ptr = nil
            return os.getenv(name)
        end

        local size = get_string_buf_size()
        env_ptr[0] = get_string_buf(size)
        local name_len_ptr = get_size_ptr()

        local rc = ngx_lua_ffi_get_conf_env(name, env_ptr, name_len_ptr)
        if rc == FFI_OK then
            return ffi_str(env_ptr[0] + name_len_ptr[0] + 1)
        end

        -- FFI_DECLINED

        local value = _getenv(name)
        if value ~= nil then
            return value
        end

        return nil
    end
end


_M._VERSION = base.version


return _M
