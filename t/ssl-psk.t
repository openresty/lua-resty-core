# vim:set ft=ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua;
use Cwd qw(abs_path realpath cwd);
use File::Basename;

#worker_connections(10140);
#workers(1);
#log_level('warn');

repeat_each(2);

plan tests => repeat_each() * (blocks() * 6 + 2);

our $CWD = cwd();

no_long_string();
#no_diff();

$ENV{TEST_NGINX_LUA_PACKAGE_PATH} = "$::CWD/lib/?.lua;;";
$ENV{TEST_NGINX_HTML_DIR} ||= html_dir();

run_tests();

__DATA__

=== TEST 1: TLS-PSK
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH/?.lua;;";
    server {
        listen unix:$TEST_NGINX_HTML_DIR/nginx.sock ssl;
        server_name   test.com;

        ssl_protocols TLSv1;
        ssl_ciphers PSK;

        ssl_certificate_by_lua_block {
            local ssl = require "ngx.ssl"

            local psk_key = "psk_test_key"

            local psk_identity, err = ssl.get_psk_identity()
            if not psk_identity then
                if err == "not in psk context" then
                    -- handler was not called by TLS-PSK callback
                    return
                end
                ngx.log(ngx.ERR, "failed to get psk identity: ", err)
                return ngx.exit(ngx.ERROR)
            end

            print("client psk identity: ", psk_identity)

            local ok, err = ssl.set_psk_key(psk_key)
            if not ok then
                ngx.log(ngx.ERR, "failed to set psk key: ", err)
                return ngx.exit(ngx.ERROR)
            end
        }

        ssl_certificate ../../cert/test.crt;
        ssl_certificate_key ../../cert/test.key;

        ssl_psk_identity_hint psk_test_identity_hint;

        server_tokens off;
        location /foo {
            default_type 'text/plain';
            content_by_lua_block { ngx.status = 201 ngx.say("foo") ngx.exit(201) }
            more_clear_headers Date;
        }
    }
--- config
    server_tokens off;

    location /t {
        lua_ssl_ciphers PSK;
        lua_ssl_psk_identity psk_test_identity;
        lua_ssl_psk_key psk_test_key;

        content_by_lua_block {
            do
                local sock = ngx.socket.tcp()

                sock:settimeout(2000)

                local ok, err = sock:connect("unix:$TEST_NGINX_HTML_DIR/nginx.sock")
                if not ok then
                    ngx.say("failed to connect: ", err)
                    return
                end

                ngx.say("connected: ", ok)

                local sess, err = sock:sslhandshake(nil, "test.com", false)
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
                        -- ngx.say("failed to recieve response status line: ", err)
                        break
                    end

                    ngx.say("received: ", line)
                end

                local ok, err = sock:close()
                ngx.say("close: ", ok, " ", err)
            end  -- do
            -- collectgarbage()
        }
    }

--- request
GET /t
--- response_body
connected: 1
ssl handshake: userdata
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
lua ssl server name: "test.com"
client psk identity: psk_test_identity

--- no_error_log
[alert]
[emerg]
[error]



=== TEST 2: TLS-PSK mismatching key
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH/?.lua;;";
    server {
        listen unix:$TEST_NGINX_HTML_DIR/nginx.sock ssl;
        server_name   test.com;

        ssl_protocols TLSv1;
        ssl_ciphers PSK;

        ssl_certificate_by_lua_block {
            local ssl = require "ngx.ssl"

            local psk_key = "psk_test_key2"

            local psk_identity, err = ssl.get_psk_identity()
            if not psk_identity then
                if err == "not in psk context" then
                    -- handler was not called by TLS-PSK callback
                    return
                end
                ngx.log(ngx.ERR, "failed to get psk identity: ", err)
                return ngx.exit(ngx.ERROR)
            end

            print("client psk identity: ", psk_identity)

            local ok, err = ssl.set_psk_key(psk_key)
            if not ok then
                ngx.log(ngx.ERR, "failed to set psk key: ", err)
                return ngx.exit(ngx.ERROR)
            end
        }

        ssl_certificate ../../cert/test.crt;
        ssl_certificate_key ../../cert/test.key;

        ssl_psk_identity_hint psk_test_identity_hint;

        server_tokens off;
        location /foo {
            default_type 'text/plain';
            content_by_lua_block { ngx.status = 201 ngx.say("foo") ngx.exit(201) }
            more_clear_headers Date;
        }
    }
--- config
    server_tokens off;

    location /t {
        lua_ssl_ciphers PSK;
        lua_ssl_psk_identity psk_test_identity;
        lua_ssl_psk_key psk_test_key;

        content_by_lua_block {
            do
                local sock = ngx.socket.tcp()

                sock:settimeout(2000)

                local ok, err = sock:connect("unix:$TEST_NGINX_HTML_DIR/nginx.sock")
                if not ok then
                    ngx.say("failed to connect: ", err)
                    return
                end

                ngx.say("connected: ", ok)

                local sess, err = sock:sslhandshake(nil, "test.com", false)
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
                        -- ngx.say("failed to recieve response status line: ", err)
                        break
                    end

                    ngx.say("received: ", line)
                end

                local ok, err = sock:close()
                ngx.say("close: ", ok, " ", err)
            end  -- do
            -- collectgarbage()
        }
    }

--- request
GET /t
--- response_body
connected: 1
failed to do SSL handshake: handshake failed

--- error_log eval
[
qr/lua ssl server name: "test.com"/s,
qr/client psk identity: psk_test_identity/s,
qr/\[error\] .*? SSL_do_handshake\(\) failed .*? alert bad record mac/s,
]

--- no_error_log
[alert]
[emerg]
