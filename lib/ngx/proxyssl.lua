-- Copyright (C) Yichun Zhang (agentzh)


local base = require "resty.core.base"
base.allows_subsystem('http', 'stream')


local ffi = require "ffi"
local C = ffi.C
local ffi_str = ffi.string
local get_request = base.get_request
local error = error
local tonumber = tonumber
local errmsg = base.get_errmsg_ptr()
local subsystem = ngx.config.subsystem


local ngx_lua_ffi_proxy_ssl_get_tls1_version


if subsystem == 'http' then
    ffi.cdef[[
    int ngx_http_lua_ffi_proxy_ssl_get_tls1_version(ngx_http_request_t *r,
        char **err);
    ]]

    ngx_lua_ffi_proxy_ssl_get_tls1_version =
        C.ngx_http_lua_ffi_proxy_ssl_get_tls1_version

elseif subsystem == 'stream' then
    ffi.cdef[[
    int ngx_stream_lua_ffi_proxy_ssl_get_tls1_version(
        ngx_stream_lua_request_t *r, char **err);
    ]]

    ngx_lua_ffi_proxy_ssl_get_tls1_version =
        C.ngx_stream_lua_ffi_proxy_ssl_get_tls1_version
end


local _M = { version = base.version }


local function get_tls1_version()

    local r = get_request()
    if not r then
        error("no request found")
    end

    local ver = ngx_lua_ffi_proxy_ssl_get_tls1_version(r, errmsg)

    ver = tonumber(ver)

    if ver >= 0 then
        return ver
    end

    -- rc == FFI_ERROR

    return nil, ffi_str(errmsg[0])
end
_M.get_tls1_version = get_tls1_version


do
    _M.SSL3_VERSION = 0x0300
    _M.TLS1_VERSION = 0x0301
    _M.TLS1_1_VERSION = 0x0302
    _M.TLS1_2_VERSION = 0x0303
    _M.TLS1_3_VERSION = 0x0304

    local map = {
        [_M.SSL3_VERSION] = "SSLv3",
        [_M.TLS1_VERSION] = "TLSv1",
        [_M.TLS1_1_VERSION] = "TLSv1.1",
        [_M.TLS1_2_VERSION] = "TLSv1.2",
        [_M.TLS1_3_VERSION] = "TLSv1.3",
    }

    function _M.get_tls1_version_str()
        local ver, err = get_tls1_version()
        if not ver then
            return nil, err
        end

        local ver_str = map[ver]
        if not ver_str then
            return nil, "unknown version"
        end

        return ver_str
    end
end


return _M
