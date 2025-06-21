-- Copyright (C) Yichun Zhang (agentzh)


local base = require "resty.core.base"
base.allows_subsystem('http', 'stream')


local ffi = require "ffi"
local C = ffi.C
local ffi_str = ffi.string
local ffi_gc = ffi.gc
local ffi_copy = ffi.copy
local ffi_sizeof = ffi.sizeof
local ffi_typeof = ffi.typeof
local ffi_new = ffi.new
local get_request = base.get_request
local error = error
local tonumber = tonumber
local format = string.format
local concat = table.concat
local errmsg = base.get_errmsg_ptr()
local get_string_buf = base.get_string_buf
local get_size_ptr = base.get_size_ptr
local FFI_DECLINED = base.FFI_DECLINED
local FFI_OK = base.FFI_OK
local subsystem = ngx.config.subsystem


local ngx_lua_ffi_ssl_set_der_certificate
local ngx_lua_ffi_ssl_clear_certs
local ngx_lua_ffi_ssl_set_der_private_key
local ngx_lua_ffi_ssl_raw_server_addr
local ngx_lua_ffi_ssl_server_port
local ngx_lua_ffi_ssl_server_name
local ngx_lua_ffi_ssl_raw_client_addr
local ngx_lua_ffi_cert_pem_to_der
local ngx_lua_ffi_priv_key_pem_to_der
local ngx_lua_ffi_ssl_get_tls1_version
local ngx_lua_ffi_parse_pem_cert
local ngx_lua_ffi_parse_pem_priv_key
local ngx_lua_ffi_parse_der_cert
local ngx_lua_ffi_parse_der_priv_key
local ngx_lua_ffi_set_cert
local ngx_lua_ffi_set_priv_key
local ngx_lua_ffi_free_cert
local ngx_lua_ffi_free_priv_key
local ngx_lua_ffi_ssl_verify_client
local ngx_lua_ffi_ssl_client_random
local ngx_lua_ffi_ssl_export_keying_material
local ngx_lua_ffi_ssl_export_keying_material_early
local ngx_lua_ffi_get_req_ssl_pointer
local ngx_lua_ffi_req_shared_ssl_ciphers


if subsystem == 'http' then
    ffi.cdef[[
    int ngx_http_lua_ffi_ssl_set_der_certificate(ngx_http_request_t *r,
        const char *data, size_t len, char **err);

    int ngx_http_lua_ffi_ssl_clear_certs(ngx_http_request_t *r, char **err);

    int ngx_http_lua_ffi_ssl_set_der_private_key(ngx_http_request_t *r,
        const char *data, size_t len, char **err);

    int ngx_http_lua_ffi_ssl_raw_server_addr(ngx_http_request_t *r, char **addr,
        size_t *addrlen, int *addrtype, char **err);

    int ngx_http_lua_ffi_ssl_server_port(ngx_http_request_t *r,
        unsigned short *server_port, char **err);

    int ngx_http_lua_ffi_ssl_server_name(ngx_http_request_t *r, char **name,
        size_t *namelen, char **err);

    int ngx_http_lua_ffi_ssl_raw_client_addr(ngx_http_request_t *r, char **addr,
        size_t *addrlen, int *addrtype, char **err);

    int ngx_http_lua_ffi_cert_pem_to_der(const unsigned char *pem,
        size_t pem_len, unsigned char *der, char **err);

    int ngx_http_lua_ffi_priv_key_pem_to_der(const unsigned char *pem,
        size_t pem_len, const unsigned char *passphrase,
        unsigned char *der, char **err);

    int ngx_http_lua_ffi_ssl_get_tls1_version(ngx_http_request_t *r,
        char **err);

    void *ngx_http_lua_ffi_parse_pem_cert(const unsigned char *pem,
        size_t pem_len, char **err);

    void *ngx_http_lua_ffi_parse_pem_priv_key(const unsigned char *pem,
        size_t pem_len, char **err);

    void *ngx_http_lua_ffi_parse_der_cert(const char *data,
        size_t len, char **err);

    void *ngx_http_lua_ffi_parse_der_priv_key(const char *data, size_t len,
        char **err) ;

    void *ngx_http_lua_ffi_get_req_ssl_pointer(void *r);

    int ngx_http_lua_ffi_set_cert(void *r, void *cdata, char **err);

    int ngx_http_lua_ffi_set_priv_key(void *r, void *cdata, char **err);

    void ngx_http_lua_ffi_free_cert(void *cdata);

    void ngx_http_lua_ffi_free_priv_key(void *cdata);

    int ngx_http_lua_ffi_ssl_verify_client(void *r,
        void *client_certs, void *trusted_certs, int depth, char **err);

    int ngx_http_lua_ffi_ssl_client_random(ngx_http_request_t *r,
        const unsigned char *out, size_t *outlen, char **err);

    int ngx_http_lua_ffi_ssl_export_keying_material(void *r,
        unsigned char *out, size_t out_size,
        const char *label, size_t llen,
        const unsigned char *ctx, size_t ctxlen, int use_ctx, char **err);

    int ngx_http_lua_ffi_ssl_export_keying_material_early(void *r,
        unsigned char *out, size_t out_size,
        const char *label, size_t llen,
        const unsigned char *ctx, size_t ctxlen, char **err);

    int ngx_http_lua_ffi_req_shared_ssl_ciphers(ngx_http_request_t *r,
        unsigned short *ciphers, unsigned short *nciphers, char **err);

    typedef struct {
        uint16_t nciphers;
        uint16_t ciphers[?];
    } ngx_lua_ssl_ciphers;
    ]]

    ngx_lua_ffi_ssl_set_der_certificate =
        C.ngx_http_lua_ffi_ssl_set_der_certificate
    ngx_lua_ffi_ssl_clear_certs = C.ngx_http_lua_ffi_ssl_clear_certs
    ngx_lua_ffi_ssl_set_der_private_key =
        C.ngx_http_lua_ffi_ssl_set_der_private_key
    ngx_lua_ffi_ssl_raw_server_addr = C.ngx_http_lua_ffi_ssl_raw_server_addr
    ngx_lua_ffi_ssl_server_port = C.ngx_http_lua_ffi_ssl_server_port
    ngx_lua_ffi_ssl_server_name = C.ngx_http_lua_ffi_ssl_server_name
    ngx_lua_ffi_ssl_raw_client_addr = C.ngx_http_lua_ffi_ssl_raw_client_addr
    ngx_lua_ffi_cert_pem_to_der = C.ngx_http_lua_ffi_cert_pem_to_der
    ngx_lua_ffi_priv_key_pem_to_der = C.ngx_http_lua_ffi_priv_key_pem_to_der
    ngx_lua_ffi_ssl_get_tls1_version = C.ngx_http_lua_ffi_ssl_get_tls1_version
    ngx_lua_ffi_parse_pem_cert = C.ngx_http_lua_ffi_parse_pem_cert
    ngx_lua_ffi_parse_pem_priv_key = C.ngx_http_lua_ffi_parse_pem_priv_key
    ngx_lua_ffi_parse_der_cert = C.ngx_http_lua_ffi_parse_der_cert
    ngx_lua_ffi_parse_der_priv_key = C.ngx_http_lua_ffi_parse_der_priv_key
    ngx_lua_ffi_set_cert = C.ngx_http_lua_ffi_set_cert
    ngx_lua_ffi_set_priv_key = C.ngx_http_lua_ffi_set_priv_key
    ngx_lua_ffi_free_cert = C.ngx_http_lua_ffi_free_cert
    ngx_lua_ffi_free_priv_key = C.ngx_http_lua_ffi_free_priv_key
    ngx_lua_ffi_ssl_verify_client = C.ngx_http_lua_ffi_ssl_verify_client
    ngx_lua_ffi_ssl_client_random = C.ngx_http_lua_ffi_ssl_client_random
    ngx_lua_ffi_ssl_export_keying_material =
        C.ngx_http_lua_ffi_ssl_export_keying_material
    ngx_lua_ffi_ssl_export_keying_material_early =
        C.ngx_http_lua_ffi_ssl_export_keying_material_early
    ngx_lua_ffi_get_req_ssl_pointer = C.ngx_http_lua_ffi_get_req_ssl_pointer
    ngx_lua_ffi_req_shared_ssl_ciphers =
        C.ngx_http_lua_ffi_req_shared_ssl_ciphers

elseif subsystem == 'stream' then
    ffi.cdef[[
    int ngx_stream_lua_ffi_ssl_set_der_certificate(ngx_stream_lua_request_t *r,
        const char *data, size_t len, char **err);

    int ngx_stream_lua_ffi_ssl_clear_certs(ngx_stream_lua_request_t *r,
        char **err);

    int ngx_stream_lua_ffi_ssl_set_der_private_key(ngx_stream_lua_request_t *r,
        const char *data, size_t len, char **err);

    int ngx_stream_lua_ffi_ssl_raw_server_addr(ngx_stream_lua_request_t *r,
        char **addr, size_t *addrlen, int *addrtype, char **err);

    int ngx_stream_lua_ffi_ssl_server_port(ngx_stream_lua_request_t *r,
        unsigned short *server_port, char **err);

    int ngx_stream_lua_ffi_ssl_server_name(ngx_stream_lua_request_t *r,
        char **name, size_t *namelen, char **err);

    int ngx_stream_lua_ffi_ssl_raw_client_addr(ngx_stream_lua_request_t *r,
        char **addr, size_t *addrlen, int *addrtype, char **err);

    int ngx_stream_lua_ffi_cert_pem_to_der(const unsigned char *pem,
        size_t pem_len, unsigned char *der, char **err);

    int ngx_stream_lua_ffi_priv_key_pem_to_der(const unsigned char *pem,
        size_t pem_len, const unsigned char *passphrase,
        unsigned char *der, char **err);

    int ngx_stream_lua_ffi_ssl_get_tls1_version(ngx_stream_lua_request_t *r,
        char **err);

    void *ngx_stream_lua_ffi_parse_pem_cert(const unsigned char *pem,
        size_t pem_len, char **err);

    void *ngx_stream_lua_ffi_parse_der_cert(const unsigned char *der,
        size_t der_len, char **err);

    void *ngx_stream_lua_ffi_parse_pem_priv_key(const unsigned char *pem,
        size_t pem_len, char **err);

    void *ngx_stream_lua_ffi_parse_der_priv_key(const unsigned char *der,
        size_t der_len, char **err);

    int ngx_stream_lua_ffi_set_cert(void *r, void *cdata, char **err);

    int ngx_stream_lua_ffi_set_priv_key(void *r, void *cdata, char **err);

    void ngx_stream_lua_ffi_free_cert(void *cdata);

    void ngx_stream_lua_ffi_free_priv_key(void *cdata);

    int ngx_stream_lua_ffi_ssl_verify_client(void *r,
        void *client_certs, void *trusted_certs, int depth, char **err);

    int ngx_stream_lua_ffi_ssl_client_random(ngx_stream_lua_request_t *r,
        unsigned char *out, size_t *outlen, char **err);
    ]]

    ngx_lua_ffi_ssl_set_der_certificate =
        C.ngx_stream_lua_ffi_ssl_set_der_certificate
    ngx_lua_ffi_ssl_clear_certs = C.ngx_stream_lua_ffi_ssl_clear_certs
    ngx_lua_ffi_ssl_set_der_private_key =
        C.ngx_stream_lua_ffi_ssl_set_der_private_key
    ngx_lua_ffi_ssl_raw_server_addr = C.ngx_stream_lua_ffi_ssl_raw_server_addr
    ngx_lua_ffi_ssl_server_port = C.ngx_stream_lua_ffi_ssl_server_port
    ngx_lua_ffi_ssl_server_name = C.ngx_stream_lua_ffi_ssl_server_name
    ngx_lua_ffi_ssl_raw_client_addr = C.ngx_stream_lua_ffi_ssl_raw_client_addr
    ngx_lua_ffi_cert_pem_to_der = C.ngx_stream_lua_ffi_cert_pem_to_der
    ngx_lua_ffi_priv_key_pem_to_der = C.ngx_stream_lua_ffi_priv_key_pem_to_der
    ngx_lua_ffi_ssl_get_tls1_version =
        C.ngx_stream_lua_ffi_ssl_get_tls1_version
    ngx_lua_ffi_parse_pem_cert = C.ngx_stream_lua_ffi_parse_pem_cert
    ngx_lua_ffi_parse_der_cert = C.ngx_stream_lua_ffi_parse_der_cert
    ngx_lua_ffi_parse_pem_priv_key = C.ngx_stream_lua_ffi_parse_pem_priv_key
    ngx_lua_ffi_parse_der_priv_key = C.ngx_stream_lua_ffi_parse_der_priv_key
    ngx_lua_ffi_set_cert = C.ngx_stream_lua_ffi_set_cert
    ngx_lua_ffi_set_priv_key = C.ngx_stream_lua_ffi_set_priv_key
    ngx_lua_ffi_free_cert = C.ngx_stream_lua_ffi_free_cert
    ngx_lua_ffi_free_priv_key = C.ngx_stream_lua_ffi_free_priv_key
    ngx_lua_ffi_ssl_verify_client = C.ngx_stream_lua_ffi_ssl_verify_client
    ngx_lua_ffi_ssl_client_random = C.ngx_stream_lua_ffi_ssl_client_random
end


local _M = { version = base.version }


local charpp = ffi.new("char*[1]")
local intp = ffi.new("int[1]")
local ushortp = ffi.new("unsigned short[1]")

do
    --https://datatracker.ietf.org/doc/html/rfc8701
    local TLS_GREASE = {
        [2570] = true,
        [6682] = true,
        [10794] = true,
        [14906] = true,
        [19018] = true,
        [23130] = true,
        [27242] = true,
        [31354] = true,
        [35466] = true,
        [39578] = true,
        [43690] = true,
        [47802] = true,
        [51914] = true,
        [56026] = true,
        [60138] = true,
        [64250] = true
    }

    -- TLS cipher suite functionality
    local tls_proto_id = {
        -- TLS 1.3 ciphers
        [0x1301] = {
            iana_name = "TLS_AES_128_GCM_SHA256",
            tls_version = 1.3,
            kex = "any",
            auth = "any",
            enc = "AESGCM(128)",
            hash = "AEAD"
        },
        [0x1302] = {
            iana_name = "TLS_AES_256_GCM_SHA384",
            tls_version = 1.3,
            kex = "any",
            auth = "any",
            enc = "AESGCM(256)",
            hash = "AEAD"
        },
        [0x1303] = {
            iana_name = "TLS_CHACHA20_POLY1305_SHA256",
            tls_version = 1.3,
            kex = "any",
            auth = "any",
            enc = "CHACHA20/POLY1305(256)",
            hash = "AEAD"
        },
        [0x1304] = {
            iana_name = "TLS_AES_128_CCM_SHA256",
            tls_version = 1.3,
            kex = "none",
            auth = "none",
            enc = "AES 128 CCM",
            hash = "SHA256"
        },
        [0x1305] = {
            iana_name = "TLS_AES_128_CCM_8_SHA256",
            tls_version = 1.3,
            kex = "none",
            auth = "none",
            enc = "AES 128 CCM 8",
            hash = "SHA256"
        },
        -- TLS 1.2 ciphers (most common ones)
        [0xc02b] = {
            iana_name = "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
            tls_version = 1.2,
            kex = "ECDH",
            auth = "ECDSA",
            enc = "AESGCM(128)",
            hash = "AEAD"
        },
        [0xc02f] = {
            iana_name = "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
            tls_version = 1.2,
            kex = "ECDH",
            auth = "RSA",
            enc = "AESGCM(128)",
            hash = "AEAD"
        },
        [0xc02c] = {
            iana_name = "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384",
            tls_version = 1.2,
            kex = "ECDH",
            auth = "ECDSA",
            enc = "AESGCM(256)",
            hash = "AEAD"
        },
        [0xc030] = {
            iana_name = "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
            tls_version = 1.2,
            kex = "ECDH",
            auth = "RSA",
            enc = "AESGCM(256)",
            hash = "AEAD"
        },
        [0x9f] = {
            iana_name = "TLS_DHE_RSA_WITH_AES_256_GCM_SHA384",
            tls_version = 1.2,
            kex = "DH",
            auth = "RSA",
            enc = "AESGCM(256)",
            hash = "AEAD"
        },
        [0xcca9] = {
            iana_name = "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256",
            tls_version = 1.2,
            kex = "ECDH",
            auth = "ECDSA",
            enc = "CHACHA20/POLY1305(256)",
            hash = "AEAD"
        },
        [0xcca8] = {
            iana_name = "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256",
            tls_version = 1.2,
            kex = "ECDH",
            auth = "RSA",
            enc = "CHACHA20/POLY1305(256)",
            hash = "AEAD"
        },
        [0xccaa] = {
            iana_name = "TLS_DHE_RSA_WITH_CHACHA20_POLY1305_SHA256",
            tls_version = 1.2,
            kex = "DH",
            auth = "RSA",
            enc = "CHACHA20/POLY1305(256)",
            hash = "AEAD"
        },
        [0x9e] = {
            iana_name = "TLS_DHE_RSA_WITH_AES_128_GCM_SHA256",
            tls_version = 1.2,
            kex = "DH",
            auth = "RSA",
            enc = "AESGCM(128)",
            hash = "AEAD"
        },
        [0xc024] = {
            iana_name = "TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384",
            tls_version = 1.2,
            kex = "ECDH",
            auth = "ECDSA",
            enc = "AES(256)",
            hash = "SHA384"
        },
        [0xc028] = {
            iana_name = "TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384",
            tls_version = 1.2,
            kex = "ECDH",
            auth = "RSA",
            enc = "AES(256)",
            hash = "SHA384"
        },
        [0x6b] = {
            iana_name = "TLS_DHE_RSA_WITH_AES_256_CBC_SHA256",
            tls_version = 1.2,
            kex = "DH",
            auth = "RSA",
            enc = "AES(256)",
            hash = "SHA256"
        },
        [0xc023] = {
            iana_name = "TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256",
            tls_version = 1.2,
            kex = "ECDH",
            auth = "ECDSA",
            enc = "AES(128)",
            hash = "SHA256"
        },
        [0xc027] = {
            iana_name = "TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256",
            tls_version = 1.2,
            kex = "ECDH",
            auth = "RSA",
            enc = "AES(128)",
            hash = "SHA256"
        },
        [0x67] = {
            iana_name = "TLS_DHE_RSA_WITH_AES_128_CBC_SHA256",
            tls_version = 1.2,
            kex = "DH",
            auth = "RSA",
            enc = "AES(128)",
            hash = "SHA256"
        },
        [0xc00a] = {
            iana_name = "TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA",
            tls_version = 1.0,
            kex = "ECDH",
            auth = "ECDSA",
            enc = "AES(256)",
            hash = "SHA1"
        },
        [0xc014] = {
            iana_name = "TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA",
            tls_version = 1.0,
            kex = "ECDH",
            auth = "RSA",
            enc = "AES(256)",
            hash = "SHA1"
        },
        [0x39] = {
            iana_name = "TLS_DHE_RSA_WITH_AES_256_CBC_SHA",
            tls_version = 0x0300,
            kex = "DH",
            auth = "RSA",
            enc = "AES(256)",
            hash = "SHA1"
        },
        [0xc009] = {
            iana_name = "TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA",
            tls_version = 1.0,
            kex = "ECDH",
            auth = "ECDSA",
            enc = "AES(128)",
            hash = "SHA1"
        },
        [0xc013] = {
            iana_name = "TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA",
            tls_version = 1.0,
            kex = "ECDH",
            auth = "RSA",
            enc = "AES(128)",
            hash = "SHA1"
        },
        [0x33] = {
            iana_name = "TLS_DHE_RSA_WITH_AES_128_CBC_SHA",
            tls_version = 0x0300,
            kex = "DH",
            auth = "RSA",
            enc = "AES(128)",
            hash = "SHA1"
        },
        [0x9d] = {
            iana_name = "TLS_RSA_WITH_AES_256_GCM_SHA384",
            tls_version = 1.2,
            kex = "RSA",
            auth = "RSA",
            enc = "AESGCM(256)",
            hash = "AEAD"
        },
        [0x9c] = {
            iana_name = "TLS_RSA_WITH_AES_128_GCM_SHA256",
            tls_version = 1.2,
            kex = "RSA",
            auth = "RSA",
            enc = "AESGCM(128)",
            hash = "AEAD"
        },
        [0x3d] = {
            iana_name = "TLS_RSA_WITH_AES_256_CBC_SHA256",
            tls_version = 1.2,
            kex = "RSA",
            auth = "RSA",
            enc = "AES(256)",
            hash = "SHA256"
        },
        [0x3c] = {
            iana_name = "TLS_RSA_WITH_AES_128_CBC_SHA256",
            tls_version = 1.2,
            kex = "RSA",
            auth = "RSA",
            enc = "AES(128)",
            hash = "SHA256"
        },
        [0x35] = {
            iana_name = "TLS_RSA_WITH_AES_256_CBC_SHA",
            tls_version = 0x0300,
            kex = "RSA",
            auth = "RSA",
            enc = "AES(256)",
            hash = "SHA1"
        },
        [0x2f] = {
            iana_name = "TLS_RSA_WITH_AES_128_CBC_SHA",
            tls_version = 0x0300,
            kex = "RSA",
            auth = "RSA",
            enc = "AES(128)",
            hash = "SHA1"
        },
        -- 其他 PSK、SRP、RSA-PSK、DHE-PSK、ECDHE-PSK 可继续补充
        -- ...
    }

    local unknown_cipher = {
        iana_name = "UNKNOWN",
        tls_version = 0,
        kex = "UNKNOWN",
        auth = "UNKNOWN",
        enc = "UNKNOWN",
        hash = "UNKNOWN"
    }

    setmetatable(tls_proto_id, {
        __index = function(t, k)
            t[k] = unknown_cipher
            return unknown_cipher
        end
    })

    -- Iterator function for ciphers
    local function iterate_ciphers(ciphers, n)
        if n < ciphers.nciphers then
            return n + 1, tls_proto_id[ciphers.ciphers[n]]
        end
    end

    -- Buffer for temporary cipher table conversion
    local ciphers_t = {}

    -- Metatype for cipher structure
    ffi.metatype('ngx_lua_ssl_ciphers', {
        __ipairs = function(ciphers)
            return iterate_ciphers, ciphers, 0
        end,
        __tostring = function(ciphers)
            for n, c in ipairs(ciphers) do
                ciphers_t[n] = type(c) == "table" and c.iana_name or
                               format("0x%.4x", c)
            end
            return concat(ciphers_t, ":", 1, ciphers.nciphers)
        end
    })

    -- Cipher type and buffer
    local ciphers_typ = ffi_typeof("ngx_lua_ssl_ciphers")
    local ciphers_buf = ffi_new("uint16_t [?]", 256)

    function _M.get_shared_ssl_ciphers()
        local r = get_request()
        if not r then
            error("no request found")
        end

        ciphers_buf[0] = 255  -- Set max number of ciphers we can hold
        local rc = ngx_lua_ffi_req_shared_ssl_ciphers(r, ciphers_buf + 1,
                                                       ciphers_buf, errmsg)
        if rc ~= FFI_OK then
            return nil, ffi_str(errmsg[0])
        end

        -- Filter out GREASE ciphers
        local filtered_count = 0
        local filtered_buf = ffi_new("uint16_t [?]", ciphers_buf[0] + 1)

        for i = 1, ciphers_buf[0] do
            local cipher_id = ciphers_buf[i]
            if not TLS_GREASE[cipher_id] then
                filtered_buf[filtered_count + 1] = cipher_id
                filtered_count = filtered_count + 1
            end
        end
        filtered_buf[0] = filtered_count

        -- Create the cipher structure
        local ciphers = ciphers_typ(filtered_count)
        ffi_copy(ciphers, filtered_buf,
                 (filtered_count + 1) * ffi_sizeof('uint16_t'))

        return ciphers
    end
end

function _M.clear_certs()
    local r = get_request()
    if not r then
        error("no request found")
    end

    local rc = ngx_lua_ffi_ssl_clear_certs(r, errmsg)
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

    local rc = ngx_lua_ffi_ssl_set_der_certificate(r, data, #data, errmsg)
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

    local rc = ngx_lua_ffi_ssl_set_der_private_key(r, data, #data, errmsg)
    if rc == FFI_OK then
        return true
    end

    return nil, ffi_str(errmsg[0])
end


local addr_types = {
    [0] = "unix",
    [1] = "inet",
    [2] = "inet6",
}


function _M.raw_server_addr()
    local r = get_request()
    if not r then
        error("no request found")
    end

    local sizep = get_size_ptr()

    local rc = ngx_lua_ffi_ssl_raw_server_addr(r, charpp, sizep, intp, errmsg)
    if rc == FFI_OK then
        local typ = addr_types[intp[0]]
        if not typ then
            return nil, nil, "unknown address type: " .. intp[0]
        end
        return ffi_str(charpp[0], sizep[0]), typ
    end

    return nil, nil, ffi_str(errmsg[0])
end


function _M.server_port()
    local r = get_request()
    if not r then
        error("no request found")
    end

    local rc = ngx_lua_ffi_ssl_server_port(r, ushortp, errmsg)
    if rc == FFI_OK then
        return ushortp[0]
    end

    return nil, ffi_str(errmsg[0])
end


function _M.server_name()
    local r = get_request()
    if not r then
        error("no request found")
    end

    local sizep = get_size_ptr()

    local rc = ngx_lua_ffi_ssl_server_name(r, charpp, sizep, errmsg)
    if rc == FFI_OK then
        return ffi_str(charpp[0], sizep[0])
    end

    if rc == FFI_DECLINED then
        return nil
    end

    return nil, ffi_str(errmsg[0])
end


function _M.raw_client_addr()
    local r = get_request()
    if not r then
        error("no request found")
    end

    local sizep = get_size_ptr()

    local rc = ngx_lua_ffi_ssl_raw_client_addr(r, charpp, sizep, intp, errmsg)
    if rc == FFI_OK then
        local typ = addr_types[intp[0]]
        if not typ then
            return nil, nil, "unknown address type: " .. intp[0]
        end
        return ffi_str(charpp[0], sizep[0]), typ
    end

    return nil, nil, ffi_str(errmsg[0])
end


function _M.cert_pem_to_der(pem)
    local outbuf = get_string_buf(#pem)

    local sz = ngx_lua_ffi_cert_pem_to_der(pem, #pem, outbuf, errmsg)
    if sz > 0 then
        return ffi_str(outbuf, sz)
    end

    return nil, ffi_str(errmsg[0])
end


function _M.priv_key_pem_to_der(pem, passphrase)
    local outbuf = get_string_buf(#pem)

    local sz = ngx_lua_ffi_priv_key_pem_to_der(pem, #pem,
                                               passphrase, outbuf, errmsg)
    if sz > 0 then
        return ffi_str(outbuf, sz)
    end

    return nil, ffi_str(errmsg[0])
end


local function get_tls1_version()

    local r = get_request()
    if not r then
        error("no request found")
    end

    local ver = ngx_lua_ffi_ssl_get_tls1_version(r, errmsg)

    ver = tonumber(ver)

    if ver >= 0 then
        return ver
    end

    -- rc == FFI_ERROR

    return nil, ffi_str(errmsg[0])
end
_M.get_tls1_version = get_tls1_version


function _M.parse_pem_cert(pem)
    local cert = ngx_lua_ffi_parse_pem_cert(pem, #pem, errmsg)
    if cert ~= nil then
        return ffi_gc(cert, ngx_lua_ffi_free_cert)
    end

    return nil, ffi_str(errmsg[0])
end


function _M.parse_pem_priv_key(pem)
    local pkey = ngx_lua_ffi_parse_pem_priv_key(pem, #pem, errmsg)
    if pkey ~= nil then
        return ffi_gc(pkey, ngx_lua_ffi_free_priv_key)
    end

    return nil, ffi_str(errmsg[0])
end


function _M.parse_der_cert(der)
    local cert = ngx_lua_ffi_parse_der_cert(der, #der, errmsg)
    if cert ~= nil then
        return ffi_gc(cert, ngx_lua_ffi_free_cert)
    end

    return nil, ffi_str(errmsg[0])
end


function _M.parse_der_priv_key(der)
    local pkey = ngx_lua_ffi_parse_der_priv_key(der, #der, errmsg)
    if pkey ~= nil then
        return ffi_gc(pkey, ngx_lua_ffi_free_priv_key)
    end

    return nil, ffi_str(errmsg[0])
end


function _M.set_cert(cert)
    local r = get_request()
    if not r then
        error("no request found")
    end

    local rc = ngx_lua_ffi_set_cert(r, cert, errmsg)
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

    local rc = ngx_lua_ffi_set_priv_key(r, priv_key, errmsg)
    if rc == FFI_OK then
        return true
    end

    return nil, ffi_str(errmsg[0])
end


function _M.verify_client(client_certs, depth, trusted_certs)
    local r = get_request()
    if not r then
        error("no request found")
    end

    if not depth then
        depth = -1
    end

    local rc = ngx_lua_ffi_ssl_verify_client(r, client_certs, trusted_certs,
                                             depth, errmsg)
    if rc == FFI_OK then
        return true
    end

    return nil, ffi_str(errmsg[0])
end


function _M.export_keying_material(length, label, context)
    local r = get_request()
    if not r then
        error("no request found")
    end

    local outbuf = get_string_buf(length)
    local use_context = context and 1 or 0
    local context_len = context and #context or 0

    local rc = ngx_lua_ffi_ssl_export_keying_material(r, outbuf, length,
        label, #label, context, context_len, use_context, errmsg)

    if rc == FFI_OK then
        return ffi_str(outbuf, length)
    end

    if rc == FFI_DECLINED then
        return nil
    end

    return nil, ffi_str(errmsg[0])
end


function _M.export_keying_material_early(length, label, context)
    local r = get_request()
    if not r then
        error("no request found")
    end

    local outbuf = get_string_buf(length)
    local context_len = context and #context or 0

    local rc = ngx_lua_ffi_ssl_export_keying_material_early(r, outbuf, length,
        label, #label, context, context_len, errmsg)

    if rc == FFI_OK then
        return ffi_str(outbuf, length)
    end

    if rc == FFI_DECLINED then
        return nil
    end

    return nil, ffi_str(errmsg[0])
end

function _M.get_req_ssl_pointer()
    local r = get_request()
    if not r then
        error("no request found")
    end

    local ssl = ngx_lua_ffi_get_req_ssl_pointer(r)
    if ssl == nil then
        return nil, "no ssl object"
    end

    return ssl
end

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


function _M.get_client_random(outlen)
    local r = get_request()
    if not r then
        error("no request found")
    end

    if outlen == nil then
        outlen = 32
    end

    local out = get_string_buf(outlen)
    local sizep = get_size_ptr()
    sizep[0] = outlen

    local rc = ngx_lua_ffi_ssl_client_random(r, out, sizep, errmsg)
    if rc == FFI_OK then
        if outlen == 0 then
            return tonumber(sizep[0])
        end

        return ffi_str(out, sizep[0])
    end

    return nil, ffi_str(errmsg[0])
end


return _M
