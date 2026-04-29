# vim:set ft= ts=4 sw=4 et fdm=marker:

use lib '.';
use t::TestCore;

repeat_each(2);

my $NginxBinary = $ENV{'TEST_NGINX_BINARY'} || 'nginx';
my $openssl_version = eval { `$NginxBinary -V 2>&1` };

if ($openssl_version =~ m/built with OpenSSL (0\S*|1\.0\S*|1\.1\.0\S*)/) {
    plan(skip_all => "too old OpenSSL, need 1.1.1, was $1");
} else {
    plan tests => repeat_each() * (blocks() * 5);
}

no_long_string();
#no_diff();

env_to_nginx("PATH=" . $ENV{'PATH'});
$ENV{TEST_NGINX_LUA_PACKAGE_PATH} = "$t::TestCore::lua_package_path";
$ENV{TEST_NGINX_HTML_DIR} ||= html_dir();

# An http_config that:
#   1. boots resty.core in init_by_lua_block (same as t::TestCore::HttpConfig);
#   2. cdef's just enough OpenSSL to build an X509_STORE from a PEM blob and
#      exposes load_store_from_pem() as a global;
#   3. stands up a TLS server on a unix socket presenting mtls_server.crt
#      (signed by mtls_ca) so the test cosocket has something to handshake
#      against.
our $TLSHttpConfig = <<_EOC_;
    lua_package_path '$t::TestCore::lua_package_path';

    init_by_lua_block {
        $t::TestCore::init_by_lua_block

        local ffi = require "ffi"
        ffi.cdef[[
            typedef struct x509_store_st X509_STORE;
            typedef struct x509_st X509;
            typedef struct bio_st BIO;
            typedef struct bio_method_st BIO_METHOD;

            X509_STORE *X509_STORE_new(void);
            int X509_STORE_add_cert(X509_STORE *ctx, X509 *x);
            void X509_STORE_free(X509_STORE *v);

            BIO_METHOD *BIO_s_mem(void);
            BIO *BIO_new(BIO_METHOD *type);
            int BIO_write(BIO *b, const void *buf, int len);
            void BIO_free(BIO *a);
            X509 *PEM_read_bio_X509(BIO *bp, X509 **x, void *cb, void *u);
            void X509_free(X509 *a);
        ]]

        function _G.load_store_from_pem(pem)
            local C = ffi.C
            local bio = C.BIO_new(C.BIO_s_mem())
            if bio == nil then return nil, "BIO_new failed" end
            if C.BIO_write(bio, pem, #pem) <= 0 then
                C.BIO_free(bio)
                return nil, "BIO_write failed"
            end
            local x509 = C.PEM_read_bio_X509(bio, nil, nil, nil)
            C.BIO_free(bio)
            if x509 == nil then return nil, "PEM_read_bio_X509 failed" end
            local store = C.X509_STORE_new()
            if store == nil then
                C.X509_free(x509)
                return nil, "X509_STORE_new failed"
            end
            if C.X509_STORE_add_cert(store, x509) ~= 1 then
                C.X509_free(x509)
                C.X509_STORE_free(store)
                return nil, "X509_STORE_add_cert failed"
            end
            C.X509_free(x509)
            return ffi.gc(store, C.X509_STORE_free)
        end
    }

    server {
        listen unix:\$TEST_NGINX_HTML_DIR/tls.sock ssl;
        ssl_certificate ../../cert/mtls_server.crt;
        ssl_certificate_key ../../cert/mtls_server.key;
        server_tokens off;

        location / {
            content_by_lua_block {
                ngx.say("hello, ", ngx.var.ssl_protocol)
            }
        }
    }
_EOC_

run_tests();

__DATA__

=== TEST 1: handshake succeeds with a custom X509 trusted store
--- http_config eval: $::TLSHttpConfig
--- config
    lua_ssl_verify_depth 2;

    location /t {
        content_by_lua_block {
            local f = assert(io.open("t/cert/mtls_ca.crt", "r"))
            local pem = f:read("*a")
            f:close()

            local store, err = load_store_from_pem(pem)
            if not store then
                ngx.say("failed to load store: ", err)
                return
            end

            local sock = ngx.socket.tcp()
            sock:settimeout(3000)

            local ok, err = sock:connect("unix:$TEST_NGINX_HTML_DIR/tls.sock")
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            local ok, err = sock:settrustedstore(store)
            if not ok then
                ngx.say("failed to settrustedstore: ", err)
                return
            end

            local sess, err = sock:sslhandshake(nil, "example.com", true)
            if not sess then
                ngx.say("failed to do SSL handshake: ", err)
                return
            end

            local req = "GET / HTTP/1.0\r\nHost: example.com\r\nConnection: close\r\n\r\n"
            local bytes, err = sock:send(req)
            if not bytes then
                ngx.say("failed to send: ", err)
                return
            end

            local line, err = sock:receive("*l")
            if not line then
                ngx.say("failed to receive: ", err)
                return
            end

            ngx.say("received: ", line)
            sock:close()
        }
    }
--- request
GET /t
--- response_body_like
^received: HTTP/1\.0 200 OK
--- no_error_log
[error]
[alert]
[crit]



=== TEST 2: handshake fails when the trusted store has the wrong CA
--- http_config eval: $::TLSHttpConfig
--- config
    location /t {
        content_by_lua_block {
            local f = assert(io.open("t/cert/test.crt", "r"))
            local pem = f:read("*a")
            f:close()

            local store, err = load_store_from_pem(pem)
            if not store then
                ngx.say("failed to load store: ", err)
                return
            end

            local sock = ngx.socket.tcp()
            sock:settimeout(3000)
            assert(sock:connect("unix:$TEST_NGINX_HTML_DIR/tls.sock"))

            local ok, err = sock:settrustedstore(store)
            if not ok then
                ngx.say("failed to settrustedstore: ", err)
                return
            end

            local sess, err = sock:sslhandshake(nil, "example.com", true)
            if sess then
                ngx.say("unexpected success")
            else
                ngx.say("handshake failed: ", err)
            end

            sock:close()
        }
    }
--- request
GET /t
--- response_body_like
^handshake failed: .*certificate verify
--- error_log
lua ssl certificate verify error
--- no_error_log
[alert]
[crit]



=== TEST 3: bad arg type is rejected before any FFI / network work
--- http_config eval: $::TLSHttpConfig
--- config
    location /t {
        content_by_lua_block {
            local sock = ngx.socket.tcp()
            sock:settimeout(3000)
            assert(sock:connect("unix:$TEST_NGINX_HTML_DIR/tls.sock"))

            local ok, err = sock:settrustedstore("not cdata")
            ngx.say("settrustedstore: ", ok, " ", err)

            sock:close()
        }
    }
--- request
GET /t
--- response_body
settrustedstore: nil bad store arg: cdata expected, got string
--- no_error_log
[error]
[alert]
[crit]



=== TEST 4: settrustedstore on a closed socket returns "closed"
--- http_config eval: $::TLSHttpConfig
--- config
    location /t {
        content_by_lua_block {
            local f = assert(io.open("t/cert/mtls_ca.crt", "r"))
            local pem = f:read("*a")
            f:close()

            local store = assert(load_store_from_pem(pem))

            local sock = ngx.socket.tcp()
            sock:settimeout(3000)
            assert(sock:connect("unix:$TEST_NGINX_HTML_DIR/tls.sock"))
            assert(sock:close())

            local ok, err = sock:settrustedstore(store)
            ngx.say("settrustedstore: ", ok, " ", err)
        }
    }
--- request
GET /t
--- response_body
settrustedstore: nil closed
--- no_error_log
[error]
[alert]
[crit]



=== TEST 5: passing nil clears the trusted store on both sides
--- http_config eval: $::TLSHttpConfig
--- config
    lua_ssl_trusted_certificate ../../cert/mtls_ca.crt;
    lua_ssl_verify_depth 2;

    location /t {
        content_by_lua_block {
            -- First set a wrong CA, then clear it. The handshake should
            -- then succeed via lua_ssl_trusted_certificate, proving the
            -- C-side slot was cleared (not just the lua-side ref).
            local f = assert(io.open("t/cert/test.crt", "r"))
            local wrong_pem = f:read("*a")
            f:close()

            local wrong_store = assert(load_store_from_pem(wrong_pem))

            local sock = ngx.socket.tcp()
            sock:settimeout(3000)
            assert(sock:connect("unix:$TEST_NGINX_HTML_DIR/tls.sock"))

            assert(sock:settrustedstore(wrong_store))
            assert(sock:settrustedstore(nil))

            local sess, err = sock:sslhandshake(nil, "example.com", true)
            if not sess then
                ngx.say("handshake failed: ", err)
                return
            end

            ngx.say("handshake ok")
            sock:close()
        }
    }
--- request
GET /t
--- response_body
handshake ok
--- no_error_log
[error]
[alert]
[crit]
