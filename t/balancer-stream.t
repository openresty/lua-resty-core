# vim:set ft= ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua::Stream 'no_plan';
use Cwd qw(cwd);

#worker_connections(1014);
#master_on();
#workers(2);
#log_level('warn');

repeat_each(1);

#plan tests => repeat_each() * (blocks() * 4 + 5);

$ENV{TEST_NGINX_CWD} = cwd();

#worker_connections(1024);
#no_diff();
no_long_string();
run_tests();

__DATA__

=== TEST 1: set current peer (separate addr and port)
--- stream_config
    lua_package_path "$TEST_NGINX_CWD/lib/?.lua;;";

    upstream backend {
        server 0.0.0.1:80;
        balancer_by_lua_block {
            print("hello from balancer by lua!")
            local b = require "ngx.balancer"
            assert(b.set_current_peer("127.0.0.3", 12345))
        }
    }
--- stream_server_config
        proxy_pass backend;
--- error_log eval
[
'[lua] balancer_by_lua:2: hello from balancer by lua! while connecting to upstream,',
qr{connect\(\) failed .*?, upstream: "127\.0\.0\.3:12345"},
]
--- no_error_log
[warn]



=== TEST 2: set current peer & next upstream (3 tries)
--- stream_config
    lua_package_path "$TEST_NGINX_CWD/lib/?.lua;;";

    proxy_next_upstream_tries 10;

    upstream backend {
        server 0.0.0.1:80;
        balancer_by_lua_block {
            print("hello from balancer by lua!")
            local b = require "ngx.balancer"
            if not ngx.ctx.tries then
                ngx.ctx.tries = 0
            end

            if ngx.ctx.tries < 2 then
                local ok, err = b.set_more_tries(1)
                if not ok then
                    return error("failed to set more tries: ", err)
                elseif err then
                    ngx.log(ngx.WARN, "set more tries: ", err)
                end
            end
            ngx.ctx.tries = ngx.ctx.tries + 1
            assert(b.set_current_peer("127.0.0.3", 12345))
        }
    }
--- stream_server_config
        proxy_pass backend;
--- grep_error_log eval: qr{connect\(\) failed .*, upstream: ".*?"}
--- grep_error_log_out eval
qr#^(?:connect\(\) failed .*?, upstream: "127.0.0.3:12345"\n){3}$#
--- no_error_log
[warn]



=== TEST 3: set current peer & next upstream (no retries)
--- stream_config
    lua_package_path "$TEST_NGINX_CWD/lib/?.lua;;";

    upstream backend {
        server 0.0.0.1:80;
        balancer_by_lua_block {
            print("hello from balancer by lua!")
            local b = require "ngx.balancer"
            if not ngx.ctx.tries then
                ngx.ctx.tries = 0
            end

            ngx.ctx.tries = ngx.ctx.tries + 1
            assert(b.set_current_peer("127.0.0.3", 12345))
        }
    }
--- stream_server_config
        proxy_pass backend;
--- grep_error_log eval: qr{connect\(\) failed .*, upstream: ".*?"}
--- grep_error_log_out eval
qr#^(?:connect\(\) failed .*?, upstream: "127.0.0.3:12345"\n){1}$#
--- no_error_log
[warn]



=== TEST 4: set current peer & next upstream (3 tries exceeding the limit)
--- SKIP
--- TODO
--- stream_config
    lua_package_path "$TEST_NGINX_CWD/lib/?.lua;;";

    proxy_next_upstream_tries 2;

    upstream backend {
        server 0.0.0.1:80;
        balancer_by_lua_block {
            local b = require "ngx.balancer"

            if not ngx.ctx.tries then
                ngx.ctx.tries = 0
            end

            if ngx.ctx.tries < 2 then
                local ok, err = b.set_more_tries(1)
                if not ok then
                    return error("failed to set more tries: ", err)
                elseif err then
                    ngx.log(ngx.WARN, "set more tries: ", err)
                end
            end
            ngx.ctx.tries = ngx.ctx.tries + 1
            assert(b.set_current_peer("127.0.0.3", 12345))
        }
    }
--- stream_server_config
        proxy_pass backend;
--- grep_error_log eval: qr{connect\(\) failed .*, upstream: ".*?"}
--- grep_error_log_out eval
qr#^(?:connect\(\) failed .*?, upstream: "127.0.0.3:12345"\n){2}$#
--- error_log
set more tries: reduced tries due to limit



=== TEST 5: set current peer (port embedded in addr)
--- stream_config
    lua_package_path "$TEST_NGINX_CWD/lib/?.lua;;";

    upstream backend {
        server 0.0.0.1:80;
        balancer_by_lua_block {
            print("hello from balancer by lua!")
            local b = require "ngx.balancer"
            assert(b.set_current_peer("127.0.0.3:12345"))
        }
    }
--- stream_server_config
        proxy_pass backend;
--- error_log eval
[
'[lua] balancer_by_lua:2: hello from balancer by lua! while connecting to upstream,',
qr{connect\(\) failed .*?, upstream: "127\.0\.0\.3:12345"},
]
--- no_error_log
[warn]



=== TEST 6: set_current_peer called in a wrong context
--- wait: 0.2
--- stream_config
    lua_package_path "$TEST_NGINX_CWD/lib/?.lua;;";

    upstream backend {
        server 127.0.0.1:$TEST_NGINX_SERVER_PORT;
        balancer_by_lua_block {
            print("hello from balancer by lua!")
        }
    }

--- stream_server_config
        proxy_pass backend;

        content_by_lua_block {
            local balancer = require "ngx.balancer"
            local ok, err = balancer.set_current_peer("127.0.0.1", 1234)
            if not ok then
                ngx.log(ngx.ERR, "failed to call: ", err)
                return
            end
            ngx.log(ngx.ALERT, "unexpected success")
        }
--- error_log eval
qr/\[error\] .*? content_by_lua.*? failed to call: API disabled in the current context/
--- no_error_log
[alert]



=== TEST 7: set_more_tries called in a wrong context
--- wait: 0.2
--- stream_config
    lua_package_path "$TEST_NGINX_CWD/lib/?.lua;;";

    upstream backend {
        server 127.0.0.1:$TEST_NGINX_SERVER_PORT;
        balancer_by_lua_block {
            print("hello from balancer by lua!")
        }
    }

--- stream_server_config
        content_by_lua_block {
            local balancer = require "ngx.balancer"
            local ok, err = balancer.set_more_tries(1)
            if not ok then
                ngx.log(ngx.ERR, "failed to call: ", err)
                return
            end
            ngx.log(ngx.ALERT, "unexpected success")
        }
--- error_log eval
qr/\[error\] .*? content_by_lua.*? failed to call: API disabled in the current context/
--- no_error_log
[alert]



=== TEST 8: https => http
--- stream_config
    lua_package_path "$TEST_NGINX_CWD/lib/?.lua;;";

    upstream backend {
        server 0.0.0.1:80;
        balancer_by_lua_block {
            local b = require "ngx.balancer"
            print("hello from balancer by lua!")
            assert(b.set_current_peer("127.0.0.1", 1234))
        }
    }

    server {
        listen 1234;

        content_by_lua_block {
            ngx.say("ok")
        }
    }

    server {
        listen 1235 ssl;
        ssl_certificate ../../cert/test.crt;
        ssl_certificate_key ../../cert/test.key;

        proxy_pass backend;
    }
--- stream_server_config
        content_by_lua_block {
            local sock, err = ngx.socket.tcp()
            assert(sock, err)

            local ok, err = sock:connect("127.0.0.1", 1235)
            if not ok then
                ngx.say("connect to stream server error: ", err)
                return
            end

            local sess, err = sock:sslhandshake(nil, "test.com", false)
            if not sess then
                ngx.say("failed to do SSL handshake: ", err)
                return
            end

            local data, err = sock:receive("*a")
            if not data then
                sock:close()
                ngx.say("receive stream response error: ", err)
                return
            end
            ngx.print(data)
        }
--- no_error_log
[alert]
[error]
--- stream_response
ok
--- grep_error_log eval: qr{hello from balancer by lua!}
--- grep_error_log_out
hello from balancer by lua!



=== TEST 9: http => https
--- stream_config
    lua_package_path "$TEST_NGINX_CWD/lib/?.lua;;";

    upstream backend {
        server 0.0.0.1:80;
        balancer_by_lua_block {
            local b = require "ngx.balancer"
            print("hello from balancer by lua!")
            assert(b.set_current_peer("127.0.0.1", 1234))
        }
    }

    server {
        listen 1234 ssl;
        ssl_certificate ../../cert/test.crt;
        ssl_certificate_key ../../cert/test.key;

        content_by_lua_block {
            ngx.say("ok")
        }
    }

    server {
        listen 1235;

        proxy_pass backend;
    }
--- stream_server_config
        content_by_lua_block {
            local sock, err = ngx.socket.tcp()
            assert(sock, err)

            local ok, err = sock:connect("127.0.0.1", 1235)
            if not ok then
                ngx.say("connect to stream server error: ", err)
                return
            end

            local sess, err = sock:sslhandshake(nil, "test.com", false)
            if not sess then
                ngx.say("failed to do SSL handshake: ", err)
                return
            end

            local data, err = sock:receive("*a")
            if not data then
                sock:close()
                ngx.say("receive stream response error: ", err)
                return
            end
            ngx.print(data)
        }
--- no_error_log
[alert]
[error]
--- stream_response
ok
--- grep_error_log eval: qr{hello from balancer by lua!}
--- grep_error_log_out
hello from balancer by lua!
