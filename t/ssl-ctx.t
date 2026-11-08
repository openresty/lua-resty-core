# vim:set ft= ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua;

repeat_each(2);
plan tests => repeat_each() * blocks() * 3;

$ENV{TEST_NGINX_HTML_DIR} ||= html_dir();
no_long_string();
log_level 'info';

add_block_preprocessor(sub {
    my $block = shift;
    my $config = $block->http_config || '';
    $config .= <<'_EOC_';
lua_package_path "$prefix/html/?.lua;./lib/?.lua;../lua-resty-lrucache/lib/?.lua;;";
_EOC_
    $block->set_value("http_config", $config);
    $block->set_value("user_files", <<'_EOC_');
>>> ssl_ctx.lua
local ffi = require "ffi"
local ssl = require "ngx.ssl"

ffi.cdef[[
    typedef struct ssl_ctx_st SSL_CTX;
    SSL_CTX *SSL_get_SSL_CTX(const void *ssl);
    int SSL_CTX_get_verify_depth(const SSL_CTX *ctx);
]]

local C = ffi.C
local _M = {}

function _M.depths()
    local ctx, err = ssl.get_req_ssl_ctx()
    assert(ctx ~= nil, err)
    assert(ffi.istype("void *", ctx))
    assert(ctx == ssl.get_req_ssl_ctx())

    local conn = assert(ssl.get_req_ssl_pointer())
    return C.SSL_CTX_get_verify_depth(ffi.cast("SSL_CTX *", ctx)),
           C.SSL_CTX_get_verify_depth(C.SSL_get_SSL_CTX(conn))
end

return _M
_EOC_
});

run_tests();

__DATA__

=== TEST 1: API reports a missing request
--- http_config
    init_by_lua_block {
        local ssl = require "ngx.ssl"
        local ok, err = pcall(ssl.get_req_ssl_ctx)
        _G.no_request_ok = ok
        _G.no_request_err = err
    }
--- config
    location /t {
        content_by_lua_block {
            ngx.say(no_request_ok, ": ", no_request_err:sub(-16))
        }
    }
--- request
GET /t
--- response_body
false: no request found
--- no_error_log
[error]


=== TEST 2: plain connection returns an error
--- config
    location /t {
        content_by_lua_block {
            local ctx, err = require("ngx.ssl").get_req_ssl_ctx()
            ngx.say(ctx == nil, ": ", err)
        }
    }
--- request
GET /t
--- response_body
true: bad request
--- no_error_log
[error]


=== TEST 3: TLS context is readable during certificate and content phases
--- http_config
    server {
        listen unix:$TEST_NGINX_HTML_DIR/ctx-3.sock ssl;
        server_name default.test;
        ssl_certificate ../../cert/test.crt;
        ssl_certificate_key ../../cert/test.key;
        ssl_verify_depth 3;

        ssl_certificate_by_lua_block {
            local session_depth, active_depth = require("ssl_ctx").depths()
            assert(session_depth == 3)
            assert(active_depth == 3)
        }

        location / {
            content_by_lua_block {
                local session_depth, active_depth = require("ssl_ctx").depths()
                ngx.say(session_depth, ":", active_depth)
            }
        }
    }
--- config
    location /t {
        content_by_lua_block {
            local sock = ngx.socket.tcp()
            assert(sock:connect("unix:$TEST_NGINX_HTML_DIR/ctx-3.sock"))
            assert(sock:sslhandshake(nil, "default.test", false))
            assert(sock:send("GET / HTTP/1.0\r\nHost: default.test\r\n\r\n"))
            local data = assert(sock:receive("*a"))
            local _, header_end = data:find("\r\n\r\n", 1, true)
            assert(header_end)
            ngx.print(data:sub(header_end + 1))
            assert(sock:close())
        }
    }
--- request
GET /t
--- response_body
3:3
--- no_error_log
[error]


=== TEST 4: SNI preserves the original session context
--- http_config
    server {
        listen unix:$TEST_NGINX_HTML_DIR/ctx-4.sock ssl;
        server_name default.test;
        ssl_certificate ../../cert/test.crt;
        ssl_certificate_key ../../cert/test.key;
        ssl_verify_depth 3;

        ssl_certificate_by_lua_block {
            local session_depth, active_depth = require("ssl_ctx").depths()
            assert(session_depth == 3)
            assert(active_depth == 3)
        }

        location / {
            content_by_lua_block {
                local session_depth, active_depth = require("ssl_ctx").depths()
                ngx.say(session_depth, ":", active_depth)
            }
        }
    }

    server {
        listen unix:$TEST_NGINX_HTML_DIR/ctx-4.sock ssl;
        server_name selected.test;
        ssl_certificate ../../cert/test.crt;
        ssl_certificate_key ../../cert/test.key;
        ssl_verify_depth 7;

        ssl_certificate_by_lua_block {
            local session_depth, active_depth = require("ssl_ctx").depths()
            assert(session_depth == 3)
            assert(active_depth == 7)
        }

        location / {
            content_by_lua_block {
                local session_depth, active_depth = require("ssl_ctx").depths()
                ngx.say(session_depth, ":", active_depth)
            }
        }
    }
--- config
    location /t {
        content_by_lua_block {
            local sock = ngx.socket.tcp()
            assert(sock:connect("unix:$TEST_NGINX_HTML_DIR/ctx-4.sock"))
            assert(sock:sslhandshake(nil, "selected.test", false))
            assert(sock:send("GET / HTTP/1.0\r\nHost: selected.test\r\n\r\n"))
            local data = assert(sock:receive("*a"))
            local _, header_end = data:find("\r\n\r\n", 1, true)
            assert(header_end)
            ngx.print(data:sub(header_end + 1))
            assert(sock:close())
        }
    }
--- request
GET /t
--- response_body
3:7
--- no_error_log
[error]


=== TEST 5: ngx.ssl loads without the optional C symbol
--- config
    location /t {
        content_by_lua_block {
            local ffi = require "ffi"
            package.loaded.ffi = setmetatable({
                C = setmetatable({}, {
                    __index = function(_, name)
                        if name == "ngx_http_lua_ffi_get_req_ssl_ctx" then
                            error("unavailable C symbol")
                        end
                        return ffi.C[name]
                    end,
                }),
            }, { __index = ffi })
            package.loaded["ngx.ssl"] = nil
            local ssl = require "ngx.ssl"
            ngx.say(ssl.get_req_ssl_ctx == nil)
            local conn, err = ssl.get_req_ssl_pointer()
            ngx.say(conn == nil, ": ", err)
        }
    }
--- request
GET /t
--- response_body
true
true: bad request
--- no_error_log
[error]
