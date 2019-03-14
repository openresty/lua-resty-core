# vim:set ft= ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua 'no_plan';
use lib '.';
use t::TestCore;

$ENV{TEST_NGINX_LUA_PACKAGE_PATH} = "$t::TestCore::lua_package_path";

run_tests();

__DATA__

=== TEST 1: use resolver in rewrite_by_lua_block
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";
--- config
    resolver 8.8.8.8;
    rewrite_by_lua "ngx.ctx.addr = require('ngx.resolver').resolve('google.com')";
    location = /resolve {
        content_by_lua "ngx.say(ngx.ctx.addr)";
    }
--- request
GET /resolve
--- response_body_like: ^\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3}$



=== TEST 2: use resolver in access_by_lua_block
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";
--- config
    resolver 8.8.8.8;
    access_by_lua "ngx.ctx.addr = require('ngx.resolver').resolve('google.com')";
    location = /resolve {
        content_by_lua "ngx.say(ngx.ctx.addr)";
    }
--- request
GET /resolve
--- response_body_like: ^\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3}$



=== TEST 3: use resolver in content_by_lua_block
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";
--- config
    resolver 8.8.8.8;
    location = /resolve {
        content_by_lua "ngx.say(require('ngx.resolver').resolve('google.com'))";
    }
--- request
GET /resolve
--- response_body_like: ^\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3}$



=== TEST 4: query IPv6 addresses
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";
--- config
    resolver 8.8.8.8;
    location = /resolve {
        content_by_lua "ngx.say(require('ngx.resolver').resolve('google.com', false, true))";
    }
--- request
GET /resolve
--- response_body_like: ^[a-fA-F0-9:]+$



=== TEST 5: pass IPv4 address to resolver
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";
--- config
    location = /resolve {
        content_by_lua "ngx.say(require('ngx.resolver').resolve('192.168.0.1'))";
    }
--- request
GET /resolve
--- response_body
192.168.0.1



=== TEST 6: pass IPv6 address to resolver
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";
--- config
    location = /resolve {
        content_by_lua "ngx.say(require('ngx.resolver').resolve('2a00:1450:4010:c05::66'))";
    }
--- request
GET /resolve
--- response_body
2a00:1450:4010:c05::66



=== TEST 7: pass non-existent domain name to resolver
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";
--- config
    resolver 8.8.8.8;
    resolver_timeout 1s;
    location = /resolve {
        content_by_lua "ngx.say(require('ngx.resolver').resolve('fake-name'))";
    }
--- request
GET /resolve
--- response_body
nilfake-name could not be resolved (3: Host not found)



=== TEST 8: check caching in Nginx resolver (2 cache hits)
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";
--- config
    resolver 8.8.8.8 valid=30s;

    location = /resolve {
        content_by_lua_block {
            local resolver = require 'ngx.resolver'
            ngx.say(resolver.resolve('google.com'))
            ngx.say(resolver.resolve('google.com'))
            ngx.say(resolver.resolve('google.com'))
        }
    }
--- request
GET /resolve
--- grep_error_log: resolve cached
--- grep_error_log_out
resolve cached
resolve cached
