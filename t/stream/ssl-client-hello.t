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

=== TEST 1: get sni name
--- stream_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";

    server {
        listen unix:$TEST_NGINX_HTML_DIR/nginx.sock ssl;
        ssl_client_hello_by_lua_block {
            local ssl_clt = require "ngx.ssl.clienthello"
            print("read SNI name from Lua: ", ssl_clt.get_client_hello_server_name())
        }
        ssl_certificate ../../cert/test.crt;
        ssl_certificate_key ../../cert/test.key;

        return 'it works!\n';
    }
--- stream_server_config
    lua_ssl_trusted_certificate ../../cert/test.crt;

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
--- error_log eval
['lua ssl server name: "test.com"']
--- no_error_log
[alert]
[emerg]



=== TEST 2: get sni name, but not set
--- stream_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";

    server {
        listen unix:$TEST_NGINX_HTML_DIR/nginx.sock ssl;
        ssl_client_hello_by_lua_block {
            local ssl_clt = require "ngx.ssl.clienthello"
            print("read SNI name from Lua: ", ssl_clt.get_client_hello_server_name())
        }
        ssl_certificate ../../cert/test.crt;
        ssl_certificate_key ../../cert/test.key;

        return 'it works!\n';
    }
--- stream_server_config
    lua_ssl_trusted_certificate ../../cert/test.crt;

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
--- error_log eval
['read SNI name from Lua: nil,']

--- no_error_log
[alert]
[emerg]



=== TEST 3: read SNI name via ssl.clienthello.get_client_hello_ext()
--- stream_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";

    server {
        listen unix:$TEST_NGINX_HTML_DIR/nginx.sock ssl;
        ssl_client_hello_by_lua_block {
            local ssl_clt = require "ngx.ssl.clienthello"
            local byte = string.byte
            local ext, err = ssl_clt.get_client_hello_ext(0)
            if not ext then
                print("failed to get_client_hello_ext(0)", err)
                ngx.exit(ngx.ERROR)
            end
            local total_len = string.len(ext)
            if total_len <= 2 then
                print("bad SSL Client Hello Extension")
                ngx.exit(ngx.ERROR)
            end
            local len = byte(ext, 1) * 256 + byte(ext, 2)
            if len + 2 ~= total_len then 
                print("bad SSL Client Hello Extension")
                ngx.exit(ngx.ERROR)
            end
            if byte(ext, 3) ~= 0 then
                print("bad SSL Client Hello Extension")
                ngx.exit(ngx.ERROR)
            end
            if total_len <= 5 then
                print("bad SSL Client Hello Extension")
                ngx.exit(ngx.ERROR)
            end
            len = byte(ext, 4) * 256 + byte(ext, 5)
            if len + 5 > total_len then
                print("bad SSL Client Hello Extension")
                ngx.exit(ngx.ERROR)
            end
            local name = string.sub(ext, 6, 6 + len -1)

            print("read SNI name from Lua: ", name)
        }
        ssl_certificate ../../cert/test.crt;
        ssl_certificate_key ../../cert/test.key;

        return 'it works!\n';
    }
--- stream_server_config
    lua_ssl_trusted_certificate ../../cert/test.crt;

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
--- error_log eval
['read SNI name from Lua: test.com,']
--- no_error_log
[alert]
[emerg]



=== TEST 4: read SNI name via ssl.clienthello.get_client_hello_ext() but set set
--- stream_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";

    server {
        listen unix:$TEST_NGINX_HTML_DIR/nginx.sock ssl;
        ssl_client_hello_by_lua_block {
            local ssl_clt = require "ngx.ssl.clienthello"
            local byte = string.byte
            local ext, err = ssl_clt.get_client_hello_ext(0)
            if not ext then
                print("failed to get_client_hello_ext(0):", err)
                ngx.exit(ngx.ERROR)
            end
            local total_len = string.len(ext)
            if total_len <= 2 then
                print("bad SSL Client Hello Extension")
                ngx.exit(ngx.ERROR)
            end
            local len = byte(ext, 1) * 256 + byte(ext, 2)
            if len + 2 ~= total_len then 
                print("bad SSL Client Hello Extension")
                ngx.exit(ngx.ERROR)
            end
            if byte(ext, 3) ~= 0 then
                print("bad SSL Client Hello Extension")
                ngx.exit(ngx.ERROR)
            end
            if total_len <= 5 then
                print("bad SSL Client Hello Extension")
                ngx.exit(ngx.ERROR)
            end
            len = byte(ext, 4) * 256 + byte(ext, 5)
            if len + 5 > total_len then
                print("bad SSL Client Hello Extension")
                ngx.exit(ngx.ERROR)
            end
            local name = string.sub(ext, 6, 6 + len -1)

            print("read SNI name from Lua: ", name)
        }
        ssl_certificate ../../cert/test.crt;
        ssl_certificate_key ../../cert/test.key;

        return 'it works!\n';
    }
--- stream_server_config
    lua_ssl_trusted_certificate ../../cert/test.crt;

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
failed to do SSL handshake: handshake failed
--- error_log eval
['failed to get_client_hello_ext(0):nil']
--- no_error_log
[alert]
[emerg]



=== TEST 5: dynamically set ssl protocol - allow TLSv1.2
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
        }
        ssl_certificate ../../cert/test.crt;
        ssl_certificate_key ../../cert/test.key;
        ssl_protocols TLSv1 TLSv1.1;
        ssl_certificate ../../cert/test.crt;
        ssl_certificate_key ../../cert/test.key;

        return 'it works!\n';
    }
--- stream_server_config
    lua_ssl_trusted_certificate ../../cert/test.crt;
    lua_ssl_protocols TLSv1.2;

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
--- error_log eval
['lua ssl server name: "test.com"']
--- no_error_log
[alert]
[emerg]



=== TEST 6: dynamically set ssl protocol - allow TLSv1.3
--- stream_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";

    server {
        listen unix:$TEST_NGINX_HTML_DIR/nginx.sock ssl;
        ssl_client_hello_by_lua_block {
            local ssl_clt = require "ngx.ssl.clienthello"
            local ok = ssl_clt.set_protocols({"TLSv1.3"})
            if not ok then
                print("failed to set_protocols")
                ngx.exit(ngx.ERROR)
            end
        }
        ssl_certificate ../../cert/test.crt;
        ssl_certificate_key ../../cert/test.key;
        ssl_protocols TLSv1 TLSv1.1;
        ssl_certificate ../../cert/test.crt;
        ssl_certificate_key ../../cert/test.key;

        return 'it works!\n';
    }
--- stream_server_config
    lua_ssl_trusted_certificate ../../cert/test.crt;
    lua_ssl_protocols TLSv1.3;

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
--- error_log eval
['lua ssl server name: "test.com"']
--- no_error_log
[alert]
[emerg]



=== TEST 7: dynamically set ssl protocol - deny TLSv1.1
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
        }
        ssl_certificate ../../cert/test.crt;
        ssl_certificate_key ../../cert/test.key;
        ssl_protocols TLSv1 TLSv1.1;
        ssl_certificate ../../cert/test.crt;
        ssl_certificate_key ../../cert/test.key;

        return 'it works!\n';
    }
--- stream_server_config
    lua_ssl_trusted_certificate ../../cert/test.crt;
    lua_ssl_protocols TLSv1.1;

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
failed to do SSL handshake: handshake failed
--- error_log eval
['lua ssl server name: "test.com"']
--- no_error_log
[alert]
[emerg]



=== TEST 8: dynamically set ssl protocol - deny TLSv1
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
        }
        ssl_certificate ../../cert/test.crt;
        ssl_certificate_key ../../cert/test.key;
        ssl_protocols TLSv1 TLSv1.1;
        ssl_certificate ../../cert/test.crt;
        ssl_certificate_key ../../cert/test.key;

        return 'it works!\n';
    }
--- stream_server_config
    lua_ssl_trusted_certificate ../../cert/test.crt;
    lua_ssl_protocols TLSv1;

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
failed to do SSL handshake: handshake failed
--- error_log eval
['lua ssl server name: "test.com"']
--- no_error_log
[alert]
[emerg]



=== TEST 9: dynamically set ssl protocol and ciphers
--- stream_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";

    server {
        listen unix:$TEST_NGINX_HTML_DIR/nginx.sock ssl;
        ssl_client_hello_by_lua_block {
            local ssl_clt = require "ngx.ssl.clienthello"
            local ok = ssl_clt.set_protocols({"TLSv1.1"})
            if not ok then
                print("failed to set_protocols")
                ngx.exit(ngx.ERROR)
            end
            -- all 1.1 ciphers
            -- ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES256-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES128-SHA:DHE-RSA-AES128-SHA:AES256-SHA:AES128-SHA:TLS_EMPTY_RENEGOTIATION_INFO_SCSV
            local ciphers = [[DHE-RSA-AES256-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES128-SHA]]
            local ok = ssl_clt.set_ciphers(ciphers, true)
            if not ok then
                print("failed to set_ciphers")
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
    lua_ssl_protocols TLSv1.1;

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
--- error_log eval
['lua ssl server name: "test.com"']
--- no_error_log
[alert]
[emerg]



=== TEST 10: dynamically set ssl protocol and ciphers - allow TLSv1.2
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
            local ok = ssl_clt.set_ciphers("ECDHE-RSA-AES128-GCM-SHA256", true)
            if not ok then
                print("failed to set_ciphers")
                ngx.exit(ngx.ERROR)
            end
        }
        ssl_certificate ../../cert/test.crt;
        ssl_certificate_key ../../cert/test.key;
        ssl_protocols TLSv1 TLSv1.1;
        ssl_certificate ../../cert/test.crt;
        ssl_certificate_key ../../cert/test.key;

        return 'it works!\n';
    }
--- stream_server_config
    lua_ssl_trusted_certificate ../../cert/test.crt;
    lua_ssl_protocols TLSv1.2;

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
--- error_log eval
['lua ssl server name: "test.com"']
--- no_error_log
[alert]
[emerg]
