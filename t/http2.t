# vim:set ft= ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

log_level('debug');
# server_port('443');
server_name('test.com');

repeat_each(2);

plan tests => repeat_each() * blocks();

our $CWD = cwd();

#no_diff();
#no_long_string();
no_shuffle();

$ENV{TEST_NGINX_USE_HTTP2} = 1;
$ENV{TEST_NGINX_LUA_PACKAGE_PATH} = "$::CWD/lib/?.lua;;";

run_tests();


__DATA__


=== TEST 1: test set http2
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH/?.lua;;";


--- config
    ssl_certificate      ../../cert/test.crt;
    ssl_certificate_key  ../../cert/test.key;

    ssl_certificate_by_lua_block {
        local ssl = require "ngx.ssl";
        ssl.set_http_version(2);
    }
    location /t {
        return 200 "ok";
    }

--- http2
--- sni
--- request
GET /t
--- ignore_response
--- error_log
LUA SSL ALPN selected: h2



=== TEST 2: test set http1.1
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH/?.lua;;";


--- config
    ssl_certificate      ../../cert/test.crt;
    ssl_certificate_key  ../../cert/test.key;

    ssl_certificate_by_lua_block {
        local ssl = require "ngx.ssl";
        ssl.set_http_version(1);
    }
    location /t {
        return 200 "ok";
    }

--- http2
--- sni
--- request
GET /t
--- ignore_response
--- error_log
LUA SSL ALPN selected: http/1.1

