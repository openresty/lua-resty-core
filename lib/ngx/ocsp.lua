-- Copyright (C) Yichun Zhang (agentzh)


local base = require "resty.core.base"
base.allows_subsystem('http')


local ffi = require "ffi"
local C = ffi.C
local ffi_new = ffi.new
local ffi_str = ffi.string
local get_request = base.get_request
local error = error
local tonumber = tonumber
local errmsg = base.get_errmsg_ptr()
local get_string_buf = base.get_string_buf
local get_string_buf_size = base.get_string_buf_size
local get_size_ptr = base.get_size_ptr
local FFI_DECLINED = base.FFI_DECLINED
local FFI_OK = base.FFI_OK
local FFI_BUSY = base.FFI_BUSY


ffi.cdef[[
typedef long time_t;

int ngx_http_lua_ffi_ssl_get_ocsp_responder_from_der_chain(
    const char *chain_data, size_t chain_len, char *out, size_t *out_size,
    char **err);

int ngx_http_lua_ffi_ssl_create_ocsp_request(const char *chain_data,
    size_t chain_len, unsigned char *out, size_t *out_size, char **err);

int ngx_http_lua_ffi_ssl_validate_ocsp_response(const unsigned char *resp,
    size_t resp_len, const char *chain_data, size_t chain_len,
    unsigned char *errbuf, size_t *errbuf_size, time_t *valid);

int ngx_http_lua_ffi_ssl_set_ocsp_status_resp(ngx_http_request_t *r,
    const unsigned char *resp, size_t resp_len, char **err);
]]


local _M = { version = base.version }


function _M.get_ocsp_responder_from_der_chain(certs, maxlen)

    local buf_size = maxlen
    if not buf_size then
        buf_size = get_string_buf_size()
    end
    local buf = get_string_buf(buf_size)

    local sizep = get_size_ptr()
    sizep[0] = buf_size

    local rc = C.ngx_http_lua_ffi_ssl_get_ocsp_responder_from_der_chain(certs,
                                                   #certs, buf, sizep, errmsg)

    if rc == FFI_DECLINED then
        return nil
    end

    if rc == FFI_OK then
        return ffi_str(buf, sizep[0])
    end

    if rc == FFI_BUSY then
        return ffi_str(buf, sizep[0]), "truncated"
    end

    return nil, ffi_str(errmsg[0])
end


function _M.create_ocsp_request(certs, maxlen)

    local buf_size = maxlen
    if not buf_size then
        buf_size = get_string_buf_size()
    end
    local buf = get_string_buf(buf_size)

    local sizep = get_size_ptr()
    sizep[0] = buf_size

    local rc = C.ngx_http_lua_ffi_ssl_create_ocsp_request(certs,
                                                          #certs, buf, sizep,
                                                          errmsg)

    if rc == FFI_OK then
        return ffi_str(buf, sizep[0])
    end

    if rc == FFI_BUSY then
        return nil, ffi_str(errmsg[0]) .. ": " .. tonumber(sizep[0])
               .. " > " .. buf_size
    end

    return nil, ffi_str(errmsg[0])
end


local next_update_p = ffi_new("time_t[1]")

function _M.validate_ocsp_response(resp, chain, max_errmsg_len)
    local errbuf_size = max_errmsg_len
    if not errbuf_size then
        errbuf_size = get_string_buf_size()
    end
    local errbuf = get_string_buf(errbuf_size)

    local sizep = get_size_ptr()
    sizep[0] = errbuf_size

    local rc = C.ngx_http_lua_ffi_ssl_validate_ocsp_response(resp, #resp,
                                                             chain, #chain,
                                                             errbuf, sizep,
                                                             next_update_p)

    if rc == FFI_OK then
        local next_update = tonumber(next_update_p[0])
        if next_update == 0 then
          next_update = nil
        end
        return true, next_update
    end

    -- rc == FFI_ERROR

    return nil, nil, ffi_str(errbuf, sizep[0])
end


function _M.set_ocsp_status_resp(ocsp_resp)
    local r = get_request()
    if not r then
        error("no request found")
    end

    local rc = C.ngx_http_lua_ffi_ssl_set_ocsp_status_resp(r, ocsp_resp,
                                                           #ocsp_resp,
                                                           errmsg)

    if rc == FFI_DECLINED then
        -- no client status req
        return true, "no status req"
    end

    if rc == FFI_OK then
        return true
    end

    -- rc == FFI_ERROR

    return nil, ffi_str(errmsg[0])
end


return _M
