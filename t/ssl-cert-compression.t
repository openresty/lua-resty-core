# vim:set ft= ts=4 sw=4 et fdm=marker:
use lib '.';
use t::TestCore;

repeat_each(2);

plan tests => repeat_each() * (blocks() * 5);

no_long_string();
#no_diff();

my $NginxBinary = $ENV{'TEST_NGINX_BINARY'} || 'nginx';
my $nginx_v = eval { `$NginxBinary -V 2>&1` } || '';

# ngx_http_lua_ffi_ssl_compress_certs() needs the RFC 8879 API that arrived
# in OpenSSL 3.2.0; everywhere else it refuses with the version error.
my ($ssl_major, $ssl_minor) = $nginx_v =~ m/built with OpenSSL (\d+)\.(\d+)/;

if (defined $ssl_major
    && $nginx_v !~ m/BoringSSL|LibreSSL/
    && ($ssl_major > 3 || ($ssl_major == 3 && $ssl_minor >= 2)))
{
    $ENV{TEST_NGINX_NO_CERT_COMP} = 0;

} else {
    $ENV{TEST_NGINX_NO_CERT_COMP} = 1;
}

# Whether zlib, brotli or zstd is built into OpenSSL is not visible from
# "nginx -V", and most distribution builds enable none of them. Set
# TEST_NGINX_CERT_COMP_ALGS=1 when yours does, and the tests then insist on
# the compression succeeding instead of accepting either outcome.
$ENV{TEST_NGINX_CERT_COMP_ALGS} ||= 0;

# This suite builds nginx from lua-nginx-module master, which carries
# ngx_http_lua_ffi_ssl_compress_certs() only once
# openresty/lua-nginx-module#2530 has landed. Until then ngx.ssl has no
# binding to call and reports "no certificate compression support", so the
# expectations below allow for that as well.

$ENV{TEST_NGINX_LUA_PACKAGE_PATH} = "$t::TestCore::lua_package_path";
$ENV{TEST_NGINX_HTML_DIR} ||= html_dir();

run_tests();

__DATA__

=== TEST 1: compress with every algorithm the library has
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";

    server {
        listen unix:$TEST_NGINX_HTML_DIR/nginx.sock ssl;
        server_name   test.com;
        ssl_certificate_by_lua_block {
            local ssl = require "ngx.ssl"

            local ok, err = ssl.clear_certs()
            if not ok then
                ngx.log(ngx.ERR, "failed to clear certs: ", err)
                return
            end

            local f = assert(io.open("t/cert/test.crt.der"))
            local cert_data = f:read("*a")
            f:close()

            ok, err = ssl.set_der_cert(cert_data)
            if not ok then
                ngx.log(ngx.ERR, "failed to set DER cert: ", err)
                return
            end

            f = assert(io.open("t/cert/test.key.der"))
            local pkey_data = f:read("*a")
            f:close()

            ok, err = ssl.set_der_priv_key(pkey_data)
            if not ok then
                ngx.log(ngx.ERR, "failed to set DER priv key: ", err)
                return
            end

            ok, err = ssl.compress_certs()
            if not ok then
                ngx.log(ngx.WARN, "compress certs failed: ", err)
                return
            end

            ngx.log(ngx.WARN, "compress certs: ok")
        }
        ssl_certificate ../../cert/test2.crt;
        ssl_certificate_key ../../cert/test2.key;

        server_tokens off;
        location /foo {
            default_type 'text/plain';
            content_by_lua_block {ngx.status = 201 ngx.say("foo") ngx.exit(201)}
            more_clear_headers Date;
        }
    }
--- config
    server_tokens off;
    lua_ssl_trusted_certificate ../../cert/test.crt;

    location /t {
        content_by_lua_block {
            local sock = ngx.socket.tcp()

            sock:settimeout(3000)

            local ok, err = sock:connect("unix:$TEST_NGINX_HTML_DIR/nginx.sock")
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            ngx.say("connected: ", ok)

            local sess, err = sock:sslhandshake(nil, "test.com", true)
            if not sess then
                ngx.say("failed to do SSL handshake: ", err)
                return
            end

            ngx.say("ssl handshake: ", type(sess))

            local req = "GET /foo HTTP/1.0\r\nHost: test.com\r\nConnection: close\r\n\r\n"
            local bytes, err = sock:send(req)
            if not bytes then
                ngx.say("failed to send http request: ", err)
                return
            end

            ngx.say("sent http request: ", bytes, " bytes.")

            while true do
                local line, err = sock:receive()
                if not line then
                    break
                end

                ngx.say("received: ", line)
            end

            local ok, err = sock:close()
            ngx.say("close: ", ok, " ", err)
        }
    }
--- request
GET /t
--- response_body
connected: 1
ssl handshake: cdata
sent http request: 56 bytes.
received: HTTP/1.1 201 Created
received: Server: nginx
received: Content-Type: text/plain
received: Content-Length: 4
received: Connection: close
received: 
received: foo
close: 1 nil
--- error_log eval
$ENV{TEST_NGINX_NO_CERT_COMP}
    ? qr/compress certs failed: (?:at least OpenSSL 3\.2\.0 required|no certificate compression support)/
    : ($ENV{TEST_NGINX_CERT_COMP_ALGS}
       ? qr/compress certs: ok/
       : qr/compress certs(?:: ok| failed: (?:SSL_get1_compressed_cert\(\) failed|no certificate compression support))/)
--- no_error_log
[error]
[alert]



=== TEST 2: compress with a named algorithm
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";

    server {
        listen unix:$TEST_NGINX_HTML_DIR/nginx.sock ssl;
        server_name   test.com;
        ssl_certificate_by_lua_block {
            local ssl = require "ngx.ssl"

            local ok, err = ssl.clear_certs()
            if not ok then
                ngx.log(ngx.ERR, "failed to clear certs: ", err)
                return
            end

            local f = assert(io.open("t/cert/test.crt.der"))
            local cert_data = f:read("*a")
            f:close()

            ok, err = ssl.set_der_cert(cert_data)
            if not ok then
                ngx.log(ngx.ERR, "failed to set DER cert: ", err)
                return
            end

            f = assert(io.open("t/cert/test.key.der"))
            local pkey_data = f:read("*a")
            f:close()

            ok, err = ssl.set_der_priv_key(pkey_data)
            if not ok then
                ngx.log(ngx.ERR, "failed to set DER priv key: ", err)
                return
            end

            ok, err = ssl.compress_certs("zlib")
            if not ok then
                ngx.log(ngx.WARN, "compress certs failed: ", err)
                return
            end

            ngx.log(ngx.WARN, "compress certs: ok")
        }
        ssl_certificate ../../cert/test2.crt;
        ssl_certificate_key ../../cert/test2.key;

        server_tokens off;
        location /foo {
            default_type 'text/plain';
            content_by_lua_block {ngx.status = 201 ngx.say("foo") ngx.exit(201)}
            more_clear_headers Date;
        }
    }
--- config
    server_tokens off;
    lua_ssl_trusted_certificate ../../cert/test.crt;

    location /t {
        content_by_lua_block {
            local sock = ngx.socket.tcp()

            sock:settimeout(3000)

            local ok, err = sock:connect("unix:$TEST_NGINX_HTML_DIR/nginx.sock")
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            ngx.say("connected: ", ok)

            local sess, err = sock:sslhandshake(nil, "test.com", true)
            if not sess then
                ngx.say("failed to do SSL handshake: ", err)
                return
            end

            ngx.say("ssl handshake: ", type(sess))

            local req = "GET /foo HTTP/1.0\r\nHost: test.com\r\nConnection: close\r\n\r\n"
            local bytes, err = sock:send(req)
            if not bytes then
                ngx.say("failed to send http request: ", err)
                return
            end

            ngx.say("sent http request: ", bytes, " bytes.")

            while true do
                local line, err = sock:receive()
                if not line then
                    break
                end

                ngx.say("received: ", line)
            end

            local ok, err = sock:close()
            ngx.say("close: ", ok, " ", err)
        }
    }
--- request
GET /t
--- response_body
connected: 1
ssl handshake: cdata
sent http request: 56 bytes.
received: HTTP/1.1 201 Created
received: Server: nginx
received: Content-Type: text/plain
received: Content-Length: 4
received: Connection: close
received: 
received: foo
close: 1 nil
--- error_log eval
$ENV{TEST_NGINX_NO_CERT_COMP}
    ? qr/compress certs failed: (?:at least OpenSSL 3\.2\.0 required|no certificate compression support)/
    : ($ENV{TEST_NGINX_CERT_COMP_ALGS}
       ? qr/compress certs: ok/
       : qr/compress certs(?:: ok| failed: (?:SSL_get1_compressed_cert\(\) failed|no certificate compression support))/)
--- no_error_log
[error]
[alert]



=== TEST 3: unknown algorithm name
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";

    server {
        listen unix:$TEST_NGINX_HTML_DIR/nginx.sock ssl;
        server_name   test.com;
        ssl_certificate_by_lua_block {
            local ssl = require "ngx.ssl"

            local ok, err = ssl.compress_certs("no-such-algorithm")
            if not ok then
                ngx.log(ngx.WARN, "compress certs failed: ", err)
            end
        }
        ssl_certificate ../../cert/test.crt;
        ssl_certificate_key ../../cert/test.key;

        server_tokens off;
        location /foo {
            default_type 'text/plain';
            content_by_lua_block {ngx.status = 201 ngx.say("foo") ngx.exit(201)}
            more_clear_headers Date;
        }
    }
--- config
    server_tokens off;
    lua_ssl_trusted_certificate ../../cert/test.crt;

    location /t {
        content_by_lua_block {
            local sock = ngx.socket.tcp()

            sock:settimeout(3000)

            local ok, err = sock:connect("unix:$TEST_NGINX_HTML_DIR/nginx.sock")
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            ngx.say("connected: ", ok)

            local sess, err = sock:sslhandshake(nil, "test.com", true)
            if not sess then
                ngx.say("failed to do SSL handshake: ", err)
                return
            end

            ngx.say("ssl handshake: ", type(sess))

            local req = "GET /foo HTTP/1.0\r\nHost: test.com\r\nConnection: close\r\n\r\n"
            local bytes, err = sock:send(req)
            if not bytes then
                ngx.say("failed to send http request: ", err)
                return
            end

            ngx.say("sent http request: ", bytes, " bytes.")

            while true do
                local line, err = sock:receive()
                if not line then
                    break
                end

                ngx.say("received: ", line)
            end

            local ok, err = sock:close()
            ngx.say("close: ", ok, " ", err)
        }
    }
--- request
GET /t
--- response_body
connected: 1
ssl handshake: cdata
sent http request: 56 bytes.
received: HTTP/1.1 201 Created
received: Server: nginx
received: Content-Type: text/plain
received: Content-Length: 4
received: Connection: close
received: 
received: foo
close: 1 nil
--- error_log
compress certs failed: unknown certificate compression algorithm: no-such-algorithm
--- no_error_log
[error]
[alert]



=== TEST 4: no certificate on the connection yet
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";

    server {
        listen unix:$TEST_NGINX_HTML_DIR/nginx.sock ssl;
        server_name   test.com;
        ssl_certificate_by_lua_block {
            local ssl = require "ngx.ssl"

            local ok, err = ssl.clear_certs()
            if not ok then
                ngx.log(ngx.ERR, "failed to clear certs: ", err)
                return
            end

            ok, err = ssl.compress_certs("zlib")
            if not ok then
                ngx.log(ngx.WARN, "compress certs failed: ", err)
            end

            local f = assert(io.open("t/cert/test.crt.der"))
            local cert_data = f:read("*a")
            f:close()

            ok, err = ssl.set_der_cert(cert_data)
            if not ok then
                ngx.log(ngx.ERR, "failed to set DER cert: ", err)
                return
            end

            f = assert(io.open("t/cert/test.key.der"))
            local pkey_data = f:read("*a")
            f:close()

            ok, err = ssl.set_der_priv_key(pkey_data)
            if not ok then
                ngx.log(ngx.ERR, "failed to set DER priv key: ", err)
                return
            end
        }
        ssl_certificate ../../cert/test2.crt;
        ssl_certificate_key ../../cert/test2.key;

        server_tokens off;
        location /foo {
            default_type 'text/plain';
            content_by_lua_block {ngx.status = 201 ngx.say("foo") ngx.exit(201)}
            more_clear_headers Date;
        }
    }
--- config
    server_tokens off;
    lua_ssl_trusted_certificate ../../cert/test.crt;

    location /t {
        content_by_lua_block {
            local sock = ngx.socket.tcp()

            sock:settimeout(3000)

            local ok, err = sock:connect("unix:$TEST_NGINX_HTML_DIR/nginx.sock")
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            ngx.say("connected: ", ok)

            local sess, err = sock:sslhandshake(nil, "test.com", true)
            if not sess then
                ngx.say("failed to do SSL handshake: ", err)
                return
            end

            ngx.say("ssl handshake: ", type(sess))

            local req = "GET /foo HTTP/1.0\r\nHost: test.com\r\nConnection: close\r\n\r\n"
            local bytes, err = sock:send(req)
            if not bytes then
                ngx.say("failed to send http request: ", err)
                return
            end

            ngx.say("sent http request: ", bytes, " bytes.")

            while true do
                local line, err = sock:receive()
                if not line then
                    break
                end

                ngx.say("received: ", line)
            end

            local ok, err = sock:close()
            ngx.say("close: ", ok, " ", err)
        }
    }
--- request
GET /t
--- response_body
connected: 1
ssl handshake: cdata
sent http request: 56 bytes.
received: HTTP/1.1 201 Created
received: Server: nginx
received: Content-Type: text/plain
received: Content-Length: 4
received: Connection: close
received: 
received: foo
close: 1 nil
--- error_log eval
$ENV{TEST_NGINX_NO_CERT_COMP}
    ? qr/compress certs failed: (?:at least OpenSSL 3\.2\.0 required|no certificate compression support)/
    : qr/compress certs failed: (?:no certificate set on this connection|no certificate compression support)/
--- no_error_log
[error]
[alert]
