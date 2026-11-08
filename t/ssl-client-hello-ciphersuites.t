# vim:set ft= ts=4 sw=4 et fdm=marker:
use lib '.';
use t::TestCore;

#worker_connections(10140);
#workers(1);
#log_level('warn');

repeat_each(2);

# All these tests need to have new openssl
my $NginxBinary = $ENV{'TEST_NGINX_BINARY'} || 'nginx';
my $openssl_version = eval { `$NginxBinary -V 2>&1` };

if ($openssl_version =~ m/built with OpenSSL (0\S*|1\.0\S*|1\.1\.0\S*)/) {
    plan(skip_all => "too old OpenSSL, need 1.1.1, was $1");
} else {
    plan tests => repeat_each() * (blocks() * 6);
}

no_long_string();
#no_diff();

if ($openssl_version =~ m/\bBoringSSL\b/) {
    $ENV{TEST_NGINX_BORINGSSL} = 1;
}

env_to_nginx("PATH=" . $ENV{'PATH'});
$ENV{TEST_NGINX_LUA_PACKAGE_PATH} = "$t::TestCore::lua_package_path";
$ENV{TEST_NGINX_HTML_DIR} ||= html_dir();

run_tests();

__DATA__

=== TEST 1: dynamically set tls1.3 protocol and ciphersuites
--- skip_nginx: 6: < 1.19.9
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";

    server {
        listen unix:$TEST_NGINX_HTML_DIR/nginx.sock ssl;
        server_name   test.com;
        ssl_client_hello_by_lua_block {
            local ssl_clt = require "ngx.ssl.clienthello"
            local ok = ssl_clt.set_protocols({"TLSv1.2", "TLSv1.3"})
            if not ok then
                print("failed to set_protocols")
                ngx.exit(ngx.ERROR)
            end
            local ok = ssl_clt.set_ciphersuites("TLS_AES_128_GCM_SHA256", true)
            if not ok then
                print("failed to set_ciphersuites")
                ngx.exit(ngx.ERROR)
            end
        }
        ssl_protocols TLSv1.1 TLSv1.2 TLSv1.3;
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
    lua_ssl_protocols TLSv1.2 TLSv1.3;

    location /t {
        content_by_lua_block {
            do
                local sock = ngx.socket.tcp()

                sock:settimeout(3000)

                local ok, err = sock:connect("unix:$TEST_NGINX_HTML_DIR/nginx.sock")
                if not ok then
                    ngx.say("failed to connect: ", err)
                    return
                end

                ngx.say("connected: ", ok)

                local sess, err = sock:sslhandshake(nil, nil, true)
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
                        -- ngx.say("failed to receive response status line: ", err)
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
--- response_body eval
qq{connected: 1
ssl handshake: cdata
sent http request: 56 bytes.
received: HTTP/1.1 201 Created
received: Server: nginx
received: Content-Type: text/plain
received: Content-Length: 4
received: Connection: close
received:\x20
received: foo
close: 1 nil
}
--- error_log eval
[qr/SSL: TLSv1.3, cipher: "TLS_AES_128_GCM_SHA256/]
--- no_error_log
[error]
[alert]
[emerg]
