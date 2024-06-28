# vim:set ft= ts=4 sw=4 et fdm=marker:
use lib '.';
use t::TestCore;

#worker_connections(1014);
#master_on();
#workers(2);
#log_level('warn');

repeat_each(2);

plan tests => repeat_each() * (blocks() * 4 + 6);

$ENV{TEST_NGINX_LUA_PACKAGE_PATH} = "$t::TestCore::lua_package_path";

#worker_connections(1024);
#no_diff();
no_long_string();
run_tests();

__DATA__

=== TEST 1: balancer 
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";

    upstream backend {
        server 0.0.0.1 down;
        balancer_by_lua_block {
            local b = require "ngx.balancer"
            assert(b.set_current_peer(ngx.var.server_addr, ngx.var.server_port))
        }
    }
--- config
    location = /t {
        proxy_pass http://backend/echo;
    }

    location = /echo {
        content_by_lua_block {
            ngx.print(ngx.var.remote_addr, ":", ngx.var.remote_port)
        }
    }
--- request
    GET /t
--- response_body eval
[
qr/127.0.0.1/,
]
--- error_code: 200
--- no_error_log
[error]
[warn]

=== TEST 2: balancer with set_proxy_bind (addr)
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";

    upstream backend {
        server 0.0.0.1 down;
        balancer_by_lua_block {
            local b = require "ngx.balancer"
            assert(b.set_current_peer(ngx.var.server_addr, ngx.var.server_port))

            assert(b.set_proxy_bind("127.0.0.4"))
        }
    }
--- config
    location = /t {
        proxy_pass http://backend/echo;
    }

    location = /echo {
        content_by_lua_block {
            ngx.print(ngx.var.remote_addr, ":", ngx.var.remote_port)
        }
    }
--- request
    GET /t
--- response_body eval
[
qr/127.0.0.4/,
]
--- error_code: 200
--- no_error_log
[error]
[warn]

=== TEST 3: balancer with set_proxy_bind (addr and port)
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";

    upstream backend {
        server 0.0.0.1 down;
        balancer_by_lua_block {
            local b = require "ngx.balancer"
            assert(b.set_current_peer(ngx.var.server_addr, ngx.var.server_port))

            assert(b.set_proxy_bind("127.0.0.8:23456"))
        }
    }
--- config
    location = /t {
        proxy_pass http://backend/echo;
    }

    location = /echo {
        content_by_lua_block {
            ngx.print(ngx.var.remote_addr, ":", ngx.var.remote_port)
        }
    }
--- request
    GET /t
--- response_body eval
[
qr/127.0.0.8/,
]
--- error_code: 200
--- no_error_log
[error]
[warn]
