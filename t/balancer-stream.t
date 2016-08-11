# vim:set ft= ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua::Stream;
use Cwd qw(cwd);

#worker_connections(1014);
#master_on();
#workers(2);
#log_level('warn');

repeat_each(2);

plan tests => repeat_each() * (blocks() * 3 + 2);

$ENV{TEST_NGINX_CWD} = cwd();

#worker_connections(1024);
#no_diff();
no_shuffle();
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
            local b = require "ngx.balancer.stream"
            assert(b.set_current_peer("127.0.0.3", 12345))
        }
    }
--- stream_server_config
    proxy_pass backend;
--- error_log eval
[
'[lua] balancer_by_lua:2: hello from balancer by lua! while connecting to upstream,',
qr{connect\(\) to failed .*?, upstream: "127\.0\.0\.3:12345"},
]
--- no_error_log
[warn]



=== TEST 2: set current peer & next upstream (3 tries)
--- skip_nginx: 4: < 1.7.5
--- stream_config
    lua_package_path "$TEST_NGINX_CWD/lib/?.lua;;";

    proxy_next_upstream_tries 10;

    upstream backend {
        server 0.0.0.1:80;
        balancer_by_lua_block {
            print("hello from balancer by lua!")
            local b = require "ngx.balancer.stream"
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
--- grep_error_log eval: qr{connect\(\) to failed .*, upstream: ".*?"}
--- grep_error_log_out eval
qr#^(?:connect\(\) to failed .*?, upstream: "127.0.0.3:12345"\n){3}$#
--- no_error_log
[warn]



=== TEST 3: set current peer & next upstream (no retries)
--- skip_nginx: 4: < 1.7.5
--- stream_config
    lua_package_path "$TEST_NGINX_CWD/lib/?.lua;;";


    upstream backend {
        server 0.0.0.1:80;
        balancer_by_lua_block {
            print("hello from balancer by lua!")
            local b = require "ngx.balancer.stream"
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
qr#^(?:connect\(\) to failed .*?, upstream: "127.0.0.3:12345"\n){1}$#
--- no_error_log
[warn]



=== TEST 4: set current peer & next upstream (3 tries exceeding the limit)
--- skip_nginx: 4: < 1.7.5
--- stream_config
    lua_package_path "$TEST_NGINX_CWD/lib/?.lua;;";

    proxy_next_upstream_tries 2;

    upstream backend {
        server 0.0.0.1:80;
        balancer_by_lua_block {
            local b = require "ngx.balancer.stream"

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
qr#^(?:connect\(\) to failed .*?, upstream: "127.0.0.3:12345"\n){2}$#
--- error_log
set more tries: reduced tries due to limit



=== TEST 5: set current peer (port embedded in addr)
--- stream_config
    lua_package_path "$TEST_NGINX_CWD/lib/?.lua;;";

    upstream backend {
        server 0.0.0.1:80;
        balancer_by_lua_block {
            print("hello from balancer by lua!")
            local b = require "ngx.balancer.stream"
            assert(b.set_current_peer("127.0.0.3:12345"))
        }
    }
--- stream_server_config
    proxy_pass backend;
--- error_log eval
[
'[lua] balancer_by_lua:2: hello from balancer by lua! while connecting to upstream,',
qr{connect\(\) to failed .*?, upstream: "127\.0\.0\.3:12345"},
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
         local balancer = require "ngx.balancer.stream"
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



=== TEST 7: get_last_failure called in a wrong context
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
        local balancer = require "ngx.balancer.stream"
        local state, status, err = balancer.get_last_failure()
        if not state and err then
            ngx.log(ngx.ERR, "failed to call: ", err)
            return
        end
        ngx.log(ngx.ALERT, "unexpected success")
    }
--- error_log eval
qr/\[error\] .*? content_by_lua.*? failed to call: API disabled in the current context/
--- no_error_log
[alert]



=== TEST 8: set_more_tries called in a wrong context
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
         local balancer = require "ngx.balancer.stream"
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



=== TEST 9: test ngx.var.upstream_addr after using more than one set_current_peer
--- wait: 0.2
--- stream_config
    lua_package_path "$TEST_NGINX_CWD/lib/?.lua;;";
    proxy_next_upstream_tries 3;

    upstream backend {
        server 127.0.0.1:$TEST_NGINX_SERVER_PORT;
        balancer_by_lua_block {
            local balancer = require "ngx.balancer.stream"
            if ngx.ctx.tries == nil then
                balancer.set_more_tries(1)
                ngx.ctx.tries = 1
                balancer.set_current_peer("127.0.0.3", 12345)
            else
                balancer.set_current_peer("127.0.0.3", 12346)
            end
        }
    }

--- stream_server_config
    proxy_pass backend;
    content_by_lua_block {
        ngx.say("ngx.var.upstream_addr is " .. ngx.var.upstream_addr)
    }
--- stream_response
ngx.var.upstream_addr is 127.0.0.3:12346
--- no_error_log
[alert]
