-- Copyright (C) Yichun Zhang (agentzh)


local base = require "resty.core.base"
base.allows_subsystem('http', 'stream')


local ffi = require "ffi"
local C = ffi.C
local ffi_str = ffi.string
local get_request = base.get_request
local error = error
local errmsg = base.get_errmsg_ptr()
local FFI_OK = base.FFI_OK
local subsystem = ngx.config.subsystem


local ngx_lua_ffi_proxy_ssl_clear_certs
local ngx_lua_ffi_proxy_ssl_set_der_certificate
local ngx_lua_ffi_proxy_ssl_set_der_private_key
local ngx_lua_ffi_proxy_ssl_set_cert
local ngx_lua_ffi_proxy_ssl_set_priv_key


if subsystem == 'http' then
    ffi.cdef[[
    int ngx_http_lua_ffi_proxy_ssl_clear_certs(ngx_http_request_t *r,
        char **err);

    int ngx_http_lua_ffi_proxy_ssl_set_der_certificate(ngx_http_request_t *r,
        const char *data, size_t len, char **err);

    int ngx_http_lua_ffi_proxy_ssl_set_der_private_key(ngx_http_request_t *r,
        const char *data, size_t len, char **err);

    int ngx_http_lua_ffi_proxy_ssl_set_cert(void *r, void *cdata, char **err);

    int ngx_http_lua_ffi_proxy_ssl_set_priv_key(void *r, void *cdata,
        char **err);
    ]]

    ngx_lua_ffi_proxy_ssl_clear_certs = C.ngx_http_lua_ffi_proxy_ssl_clear_certs
    ngx_lua_ffi_proxy_ssl_set_der_certificate =
        C.ngx_http_lua_ffi_proxy_ssl_set_der_certificate
    ngx_lua_ffi_proxy_ssl_set_der_private_key =
        C.ngx_http_lua_ffi_proxy_ssl_set_der_private_key
    ngx_lua_ffi_proxy_ssl_set_cert = C.ngx_http_lua_ffi_proxy_ssl_set_cert
    ngx_lua_ffi_proxy_ssl_set_priv_key =
        C.ngx_http_lua_ffi_proxy_ssl_set_priv_key

elseif subsystem == 'stream' then
    ffi.cdef[[
    int ngx_stream_lua_ffi_proxy_ssl_clear_certs(ngx_stream_lua_request_t *r,
        char **err);

    int ngx_stream_lua_ffi_proxy_ssl_set_der_certificate(
        ngx_stream_lua_request_t *r, const char *data, size_t len, char **err);

    int ngx_stream_lua_ffi_proxy_ssl_set_der_private_key(
        ngx_stream_lua_request_t *r, const char *data, size_t len, char **err);

    int ngx_stream_lua_ffi_proxy_ssl_set_cert(ngx_stream_lua_request_t *r,
        void *cdata, char **err);

    int ngx_stream_lua_ffi_proxy_ssl_set_priv_key(ngx_stream_lua_request_t *r,
        void *cdata, char **err);
    ]]

    ngx_lua_ffi_proxy_ssl_clear_certs =
        C.ngx_stream_lua_ffi_proxy_ssl_clear_certs
    ngx_lua_ffi_proxy_ssl_set_der_certificate =
        C.ngx_stream_lua_ffi_proxy_ssl_set_der_certificate
    ngx_lua_ffi_proxy_ssl_set_der_private_key =
        C.ngx_stream_lua_ffi_proxy_ssl_set_der_private_key
    ngx_lua_ffi_proxy_ssl_set_cert = C.ngx_stream_lua_ffi_proxy_ssl_set_cert
    ngx_lua_ffi_proxy_ssl_set_priv_key =
        C.ngx_stream_lua_ffi_proxy_ssl_set_priv_key
end


local _M = { version = base.version }


function _M.clear_certs()
    local r = get_request()
    if not r then
        error("no request found")
    end

    local rc = ngx_lua_ffi_proxy_ssl_clear_certs(r, errmsg)
    if rc == FFI_OK then
        return true
    end

    return nil, ffi_str(errmsg[0])
end


function _M.set_der_cert(data)
    local r = get_request()
    if not r then
        error("no request found")
    end

    local rc = ngx_lua_ffi_proxy_ssl_set_der_certificate(r, data, #data, errmsg)
    if rc == FFI_OK then
        return true
    end

    return nil, ffi_str(errmsg[0])
end


function _M.set_der_priv_key(data)
    local r = get_request()
    if not r then
        error("no request found")
    end

    local rc = ngx_lua_ffi_proxy_ssl_set_der_private_key(r, data, #data, errmsg)
    if rc == FFI_OK then
        return true
    end

    return nil, ffi_str(errmsg[0])
end


function _M.set_cert(cert)
    local r = get_request()
    if not r then
        error("no request found")
    end

    local rc = ngx_lua_ffi_proxy_ssl_set_cert(r, cert, errmsg)
    if rc == FFI_OK then
        return true
    end

    return nil, ffi_str(errmsg[0])
end


function _M.set_priv_key(priv_key)
    local r = get_request()
    if not r then
        error("no request found")
    end

    local rc = ngx_lua_ffi_proxy_ssl_set_priv_key(r, priv_key, errmsg)
    if rc == FFI_OK then
        return true
    end

    return nil, ffi_str(errmsg[0])
end


return _M
