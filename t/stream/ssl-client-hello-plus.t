# vim:set ft= ts=4 sw=4 et fdm=marker:
use lib '.';
use t::TestCore::Stream;

#worker_connections(10140);
#workers(1);
#log_level('warn');

repeat_each(2);

plan tests => repeat_each() * (blocks() * 5);

no_long_string();
#no_diff();

my $NginxBinary = $ENV{'TEST_NGINX_BINARY'} || 'nginx';
my $openssl_version = eval { `$NginxBinary -V 2>&1` };

if ($openssl_version =~ m/\bBoringSSL\b/) {
    $ENV{TEST_NGINX_BORINGSSL} = 1;
}

env_to_nginx("PATH=" . $ENV{'PATH'});
$ENV{TEST_NGINX_LUA_PACKAGE_PATH} = "$t::TestCore::Stream::lua_package_path";
$ENV{TEST_NGINX_HTML_DIR} ||= html_dir();

run_tests();

__DATA__

=== TEST 1: dynamically set ssl protocol and ciphers
--- stream_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";

    server {
        listen unix:$TEST_NGINX_HTML_DIR/nginx.sock ssl;
        ssl_client_hello_by_lua_block {
            local ssl_clt = require "ngx.ssl.clienthello"
            local ok = ssl_clt.set_protocols({"TLSv1.2", "TLSv1.3"})
            if not ok then
                print("failed to set_protocols")
                ngx.exit(ngx.ERROR)
            end
            local ciphers = [[TLS_AES_128_GCM_SHA256]]
            local ok = ssl_clt.set_ciphersuites(ciphers, true)
            if not ok then
                print("failed to set_ciphersuites")
                ngx.exit(ngx.ERROR)
            end
        }
        ssl_certificate ../../cert/test.crt;
        ssl_certificate_key ../../cert/test.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_certificate ../../cert/test.crt;
        ssl_certificate_key ../../cert/test.key;

        return 'it works!\n';
    }
--- stream_server_config
    lua_ssl_trusted_certificate ../../cert/test.crt;
    lua_ssl_protocols TLSv1.2 TLSv1.3;

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

            local sess, err = sock:sslhandshake(nil, "test.com", true)
            if not sess then
                ngx.say("failed to do SSL handshake: ", err)
                return
            end

            ngx.say("ssl handshake: ", type(sess))

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

--- stream_response
connected: 1
ssl handshake: userdata
received: it works!
close: 1 nil
--- error_log
cipher: "TLS_AES_128_GCM_SHA256 TLSv1.3
--- no_error_log
[alert]
[emerg]



=== TEST 2: dynamically set ssl protocol and ciphers - allow TLSv1.3
--- stream_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";

    server {
        listen unix:$TEST_NGINX_HTML_DIR/nginx.sock ssl;
        ssl_client_hello_by_lua_block {
            local ssl_clt = require "ngx.ssl.clienthello"
            local ok = ssl_clt.set_protocols({"TLSv1.2", "TLSv1.3"})
            if not ok then
                print("failed to set_protocols")
                ngx.exit(ngx.ERROR)
            end
            local ok = ssl_clt.set_ciphersuites("TLS_CHACHA20_POLY1305_SHA256", true)
            if not ok then
                print("failed to set_ciphers")
                ngx.exit(ngx.ERROR)
            end
        }
        ssl_certificate ../../cert/test.crt;
        ssl_certificate_key ../../cert/test.key;
        ssl_protocols TLSv1.1 TLSv1.2 TLSv1.3;
        ssl_certificate ../../cert/test.crt;
        ssl_certificate_key ../../cert/test.key;

        return 'it works!\n';
    }
--- stream_server_config
    lua_ssl_trusted_certificate ../../cert/test.crt;
    lua_ssl_protocols TLSv1.2 TLSv1.3;

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

            local sess, err = sock:sslhandshake(nil, "test.com", true)
            if not sess then
                ngx.say("failed to do SSL handshake: ", err)
                return
            end

            ngx.say("ssl handshake: ", type(sess))

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

--- stream_response
connected: 1
ssl handshake: userdata
received: it works!
close: 1 nil
--- error_log
cipher: "TLS_CHACHA20_POLY1305_SHA256 TLSv1.3
--- no_error_log
[alert]
[emerg]
