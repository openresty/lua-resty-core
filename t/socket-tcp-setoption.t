# vim:set ft= ts=4 sw=4 et fdm=marker:

use lib '.';
use t::TestCore;

repeat_each(2);

plan tests => repeat_each() * (blocks() * 3) - 2;

#worker_connections(1024);
#no_diff();
no_long_string();

run_tests();

__DATA__

=== TEST 1: no parameters.
--- config
    set $port $TEST_NGINX_SERVER_PORT;

    location /t {
        content_by_lua_block {
            require "resty.core.socket"

            local port = ngx.var.port
            local sock = ngx.socket.tcp()
            local ok, err = sock:connect("127.0.0.1", port)
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            ok, err = sock:setoption()
            if not ok then
                ngx.say("setoption failed: ", err)
            end

            ok, err = sock:setoption("sndbuf")
            if not ok then
                ngx.say("setoption failed: ", err)
            end

            sock:close()
        }
    }
--- request
GET /t
--- response_body
setoption failed: missing the "option" argument
setoption failed: missing the "value" argument
--- no_error_log
[error]



=== TEST 2: unsuppotrted option name.
--- config
    set $port $TEST_NGINX_SERVER_PORT;

    location /t {
        content_by_lua_block {
            require "resty.core.socket"

            local port = ngx.var.port
            local sock = ngx.socket.tcp()
            local ok, err = sock:connect("127.0.0.1", port)
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            local ok, err = sock:setoption("abc", 123)
            if not ok then
                ngx.say("setoption abc failed: ", err)
                return
            end

            sock:close()
        }
    }
--- request
GET /t
--- response_body
setoption abc failed: unsupported option abc
--- no_error_log
[error]



=== TEST 3: getoption before calling connect.
--- config
    set $port $TEST_NGINX_SERVER_PORT;

    location /t {
        content_by_lua_block {
            require "resty.core.socket"

            local sock = ngx.socket.tcp()
            local sndbuf, err = sock:setoption("so_sndbuf", 4000)
            if not sndbuf then
                ngx.say("getoption so_sndbuf failed: ", err)
                return
            end

            sock:close()
        }
    }
--- request
GET /t
--- error_code: 500
--- error_log
bad tcp socket



=== TEST 4: keepalive set by 1/0.
--- config
    set $port $TEST_NGINX_SERVER_PORT;

    location /t {
        content_by_lua_block {
            require "resty.core.socket"

            local port = ngx.var.port
            local sock = ngx.socket.tcp()
            local ok, err = sock:connect("127.0.0.1", port)
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end
            local v1, err = sock:getoption("keepalive")
            if not v1 then
                ngx.say("get default keepalive failed: ", err)
                return
            end

            ok, err = sock:setoption("keepalive", 1)
            if not ok then
                ngx.say("enable keepalive failed: ", err)
                return
            end
            local v2, err = sock:getoption("keepalive")
            if not v2 then
                ngx.say("get enabled keepalive failed: ", err)
                return
            end
            ngx.say("keepalive change from ", v1, " to ", v2)

            ok, err = sock:setoption("keepalive", 0)
            if not ok then
                ngx.say("disable keepalive failed: ", err)
                return
            end
            local v3, err = sock:getoption("keepalive")
            if not v3 then
                ngx.say("get disabled keepalive failed: ", err)
                return
            end
            ngx.say("keepalive change from ", v2, " to ", v3)

            sock:close()
        }
    }
--- request
GET /t
--- response_body
keepalive change from 0 to 1
keepalive change from 1 to 0
--- no_error_log
[error]



=== TEST 5: keepalive set by true/false.
--- config
    set $port $TEST_NGINX_SERVER_PORT;

    location /t {
        content_by_lua_block {
            require "resty.core.socket"

            local port = ngx.var.port
            local sock = ngx.socket.tcp()
            local ok, err = sock:connect("127.0.0.1", port)
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end
            local v1, err = sock:getoption("keepalive")
            if not v1 then
                ngx.say("get default keepalive failed: ", err)
                return
            end

            ok, err = sock:setoption("keepalive", true)
            if not ok then
                ngx.say("enable keepalive failed: ", err)
                return
            end
            local v2, err = sock:getoption("keepalive")
            if not v2 then
                ngx.say("get enabled keepalive failed: ", err)
                return
            end
            ngx.say("keepalive change from ", v1, " to ", v2)

            ok, err = sock:setoption("keepalive", false)
            if not ok then
                ngx.say("disable keepalive failed: ", err)
                return
            end
            local v3, err = sock:getoption("keepalive")
            if not v3 then
                ngx.say("get disabled keepalive failed: ", err)
                return
            end
            ngx.say("keepalive change from ", v2, " to ", v3)

            sock:close()
        }
    }
--- request
GET /t
--- response_body
keepalive change from 0 to 1
keepalive change from 1 to 0
--- no_error_log
[error]



=== TEST 6: keepalive set by ~0/0.
--- config
    set $port $TEST_NGINX_SERVER_PORT;

    location /t {
        content_by_lua_block {
            require "resty.core.socket"

            local port = ngx.var.port
            local sock = ngx.socket.tcp()
            local ok, err = sock:connect("127.0.0.1", port)
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end
            local v1, err = sock:getoption("keepalive")
            if not v1 then
                ngx.say("get default keepalive failed: ", err)
                return
            end

            ok, err = sock:setoption("keepalive", 10)
            if not ok then
                ngx.say("enable keepalive failed: ", err)
                return
            end
            local v2, err = sock:getoption("keepalive")
            if not v2 then
                ngx.say("get enabled keepalive failed: ", err)
                return
            end
            ngx.say("keepalive change from ", v1, " to ", v2)

            ok, err = sock:setoption("keepalive", 0)
            if not ok then
                ngx.say("disable keepalive failed: ", err)
                return
            end
            local v3, err = sock:getoption("keepalive")
            if not v3 then
                ngx.say("get disabled keepalive failed: ", err)
                return
            end
            ngx.say("keepalive change from ", v2, " to ", v3)

            sock:close()
        }
    }
--- request
GET /t
--- response_body
keepalive change from 0 to 1
keepalive change from 1 to 0
--- no_error_log
[error]



=== TEST 7: reuseaddr set by 1/0.
--- config
    set $port $TEST_NGINX_SERVER_PORT;

    location /t {
        content_by_lua_block {
            require "resty.core.socket"

            local port = ngx.var.port
            local sock = ngx.socket.tcp()
            local ok, err = sock:connect("127.0.0.1", port)
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end
            local v1, err = sock:getoption("reuseaddr")
            if not v1 then
                ngx.say("get default reuseaddr failed: ", err)
                return
            end

            ok, err = sock:setoption("reuseaddr", 1)
            if not ok then
                ngx.say("enable reuseaddr failed: ", err)
                return
            end
            local v2, err = sock:getoption("reuseaddr")
            if not v2 then
                ngx.say("get enabled reuseaddr failed: ", err)
                return
            end
            ngx.say("reuseaddr change from ", v1, " to ", v2)

            ok, err = sock:setoption("reuseaddr", 0)
            if not ok then
                ngx.say("disable reuseaddr failed: ", err)
                return
            end
            local v3, err = sock:getoption("reuseaddr")
            if not v3 then
                ngx.say("get disabled reuseaddr failed: ", err)
                return
            end
            ngx.say("reuseaddr change from ", v2, " to ", v3)

            sock:close()
        }
    }
--- request
GET /t
--- response_body
reuseaddr change from 0 to 1
reuseaddr change from 1 to 0
--- no_error_log
[error]



=== TEST 8: reuseaddr set by true/false.
--- config
    set $port $TEST_NGINX_SERVER_PORT;

    location /t {
        content_by_lua_block {
            require "resty.core.socket"

            local port = ngx.var.port
            local sock = ngx.socket.tcp()
            local ok, err = sock:connect("127.0.0.1", port)
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end
            local v1, err = sock:getoption("reuseaddr")
            if not v1 then
                ngx.say("get default reuseaddr failed: ", err)
                return
            end

            ok, err = sock:setoption("reuseaddr", true)
            if not ok then
                ngx.say("enable reuseaddr failed: ", err)
                return
            end
            local v2, err = sock:getoption("reuseaddr")
            if not v2 then
                ngx.say("get enabled reuseaddr failed: ", err)
                return
            end
            ngx.say("reuseaddr change from ", v1, " to ", v2)

            ok, err = sock:setoption("reuseaddr", false)
            if not ok then
                ngx.say("disable reuseaddr failed: ", err)
                return
            end
            local v3, err = sock:getoption("reuseaddr")
            if not v3 then
                ngx.say("get disabled reuseaddr failed: ", err)
                return
            end
            ngx.say("reuseaddr change from ", v2, " to ", v3)

            sock:close()
        }
    }
--- request
GET /t
--- response_body
reuseaddr change from 0 to 1
reuseaddr change from 1 to 0
--- no_error_log
[error]



=== TEST 9: reuseaddr set by ~0/0.
--- config
    set $port $TEST_NGINX_SERVER_PORT;

    location /t {
        content_by_lua_block {
            require "resty.core.socket"

            local port = ngx.var.port
            local sock = ngx.socket.tcp()
            local ok, err = sock:connect("127.0.0.1", port)
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end
            local v1, err = sock:getoption("reuseaddr")
            if not v1 then
                ngx.say("get default reuseaddr failed: ", err)
                return
            end

            ok, err = sock:setoption("reuseaddr", 10)
            if not ok then
                ngx.say("enable reuseaddr failed: ", err)
                return
            end
            local v2, err = sock:getoption("reuseaddr")
            if not v2 then
                ngx.say("get enabled reuseaddr failed: ", err)
                return
            end
            ngx.say("reuseaddr change from ", v1, " to ", v2)

            ok, err = sock:setoption("reuseaddr", 0)
            if not ok then
                ngx.say("disable reuseaddr failed: ", err)
                return
            end
            local v3, err = sock:getoption("reuseaddr")
            if not v3 then
                ngx.say("get disabled reuseaddr failed: ", err)
                return
            end
            ngx.say("reuseaddr change from ", v2, " to ", v3)

            sock:close()
        }
    }
--- request
GET /t
--- response_body
reuseaddr change from 0 to 1
reuseaddr change from 1 to 0
--- no_error_log
[error]



=== TEST 10: tcp-nodelay set by 1/0.
--- config
    set $port $TEST_NGINX_SERVER_PORT;

    location /t {
        content_by_lua_block {
            require "resty.core.socket"

            local port = ngx.var.port
            local sock = ngx.socket.tcp()
            local ok, err = sock:connect("127.0.0.1", port)
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end
            local v1, err = sock:getoption("tcp-nodelay")
            if not v1 then
                ngx.say("get default tcp-nodelay failed: ", err)
                return
            end

            ok, err = sock:setoption("tcp-nodelay", 1)
            if not ok then
                ngx.say("enable tcp-nodelay failed: ", err)
                return
            end
            local v2, err = sock:getoption("tcp-nodelay")
            if not v2 then
                ngx.say("get enabled tcp-nodelay failed: ", err)
                return
            end
            ngx.say("tcp-nodelay change from ", v1, " to ", v2)

            ok, err = sock:setoption("tcp-nodelay", 0)
            if not ok then
                ngx.say("disable tcp-nodelay failed: ", err)
                return
            end
            local v3, err = sock:getoption("tcp-nodelay")
            if not v3 then
                ngx.say("get disabled tcp-nodelay failed: ", err)
                return
            end
            ngx.say("tcp-nodelay change from ", v2, " to ", v3)

            sock:close()
        }
    }
--- request
GET /t
--- response_body
tcp-nodelay change from 0 to 1
tcp-nodelay change from 1 to 0
--- no_error_log
[error]



=== TEST 11: tcp-nodelay set by true/false.
--- config
    set $port $TEST_NGINX_SERVER_PORT;

    location /t {
        content_by_lua_block {
            require "resty.core.socket"

            local port = ngx.var.port
            local sock = ngx.socket.tcp()
            local ok, err = sock:connect("127.0.0.1", port)
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end
            local v1, err = sock:getoption("tcp-nodelay")
            if not v1 then
                ngx.say("get default tcp-nodelay failed: ", err)
                return
            end

            ok, err = sock:setoption("tcp-nodelay", true)
            if not ok then
                ngx.say("enable tcp-nodelay failed: ", err)
                return
            end
            local v2, err = sock:getoption("tcp-nodelay")
            if not v2 then
                ngx.say("get enabled tcp-nodelay failed: ", err)
                return
            end
            ngx.say("tcp-nodelay change from ", v1, " to ", v2)

            ok, err = sock:setoption("tcp-nodelay", false)
            if not ok then
                ngx.say("disable tcp-nodelay failed: ", err)
                return
            end
            local v3, err = sock:getoption("tcp-nodelay")
            if not v3 then
                ngx.say("get disabled tcp-nodelay failed: ", err)
                return
            end
            ngx.say("tcp-nodelay change from ", v2, " to ", v3)

            sock:close()
        }
    }
--- request
GET /t
--- response_body
tcp-nodelay change from 0 to 1
tcp-nodelay change from 1 to 0
--- no_error_log
[error]



=== TEST 12: tcp-nodelay set by ~0/0.
--- config
    set $port $TEST_NGINX_SERVER_PORT;

    location /t {
        content_by_lua_block {
            require "resty.core.socket"

            local port = ngx.var.port
            local sock = ngx.socket.tcp()
            local ok, err = sock:connect("127.0.0.1", port)
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end
            local v1, err = sock:getoption("tcp-nodelay")
            if not v1 then
                ngx.say("get default tcp-nodelay failed: ", err)
                return
            end

            ok, err = sock:setoption("tcp-nodelay", 10)
            if not ok then
                ngx.say("enable tcp-nodelay failed: ", err)
                return
            end
            local v2, err = sock:getoption("tcp-nodelay")
            if not v2 then
                ngx.say("get enabled tcp-nodelay failed: ", err)
                return
            end
            ngx.say("tcp-nodelay change from ", v1, " to ", v2)

            ok, err = sock:setoption("tcp-nodelay", 0)
            if not ok then
                ngx.say("disable tcp-nodelay failed: ", err)
                return
            end
            local v3, err = sock:getoption("tcp-nodelay")
            if not v3 then
                ngx.say("get disabled tcp-nodelay failed: ", err)
                return
            end
            ngx.say("tcp-nodelay change from ", v2, " to ", v3)

            sock:close()
        }
    }
--- request
GET /t
--- response_body
tcp-nodelay change from 0 to 1
tcp-nodelay change from 1 to 0
--- no_error_log
[error]



=== TEST 13: sndbuf.
--- config
    set $port $TEST_NGINX_SERVER_PORT;

    location /t {
        content_by_lua_block {
            require "resty.core.socket"

            local port = ngx.var.port
            local sock = ngx.socket.tcp()
            local ok, err = sock:connect("127.0.0.1", port)
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end
            local v1, err = sock:getoption("sndbuf")
            if not v1 then
                ngx.say("get default sndbuf failed: ", err)
                return
            end

            ok, err = sock:setoption("sndbuf", 4096)
            if not ok then
                ngx.say("enable sndbuf failed: ", err)
                return
            end
            local v2, err = sock:getoption("sndbuf")
            if not v2 then
                ngx.say("get enabled sndbuf failed: ", err)
                return
            end
            ngx.say("sndbuf change from ", v1, " to ", v2)

            sock:close()
        }
    }
--- request
GET /t
--- response_body_like eval
qr/sndbuf change from \d+ to \d+/
--- no_error_log
[error]



=== TEST 14: rcvbuf.
--- config
    set $port $TEST_NGINX_SERVER_PORT;

    location /t {
        content_by_lua_block {
            require "resty.core.socket"

            local port = ngx.var.port
            local sock = ngx.socket.tcp()
            local ok, err = sock:connect("127.0.0.1", port)
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end
            local v1, err = sock:getoption("rcvbuf")
            if not v1 then
                ngx.say("get default rcvbuf failed: ", err)
                return
            end

            ok, err = sock:setoption("rcvbuf", 4096)
            if not ok then
                ngx.say("enable rcvbuf failed: ", err)
                return
            end
            local v2, err = sock:getoption("rcvbuf")
            if not v2 then
                ngx.say("get enabled rcvbuf failed: ", err)
                return
            end
            ngx.say("rcvbuf change from ", v1, " to ", v2)

            sock:close()
        }
    }
--- request
GET /t
--- response_body_like eval
qr/rcvbuf change from \d+ to \d+/
--- no_error_log
[error]
