# vim:set ft= ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua::Stream;

repeat_each(2);
plan tests => repeat_each() * blocks() * 3;

$ENV{TEST_NGINX_HTML_DIR} ||= html_dir();
no_long_string();
log_level 'info';

add_block_preprocessor(sub {
    my $block = shift;
    my $config = $block->stream_config || '';
    $config .= <<'_EOC_';
lua_package_path "$prefix/html/?.lua;./lib/?.lua;../lua-resty-lrucache/lib/?.lua;;";
_EOC_
    $block->set_value("stream_config", $config);
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
--- stream_config
    init_by_lua_block {
        local ssl = require "ngx.ssl"
        local ok, err = pcall(ssl.get_req_ssl_ctx)
        _G.no_request_ok = ok
        _G.no_request_err = err
    }
--- stream_server_config
        content_by_lua_block {
            ngx.say(no_request_ok, ": ", no_request_err:sub(-16))
        }
--- stream_response
false: no request found
--- no_error_log
[error]


=== TEST 2: plain connection returns an error
--- stream_server_config
        content_by_lua_block {
            local ctx, err = require("ngx.ssl").get_req_ssl_ctx()
            ngx.say(ctx == nil, ": ", err)
        }
--- stream_response
true: bad request
--- no_error_log
[error]


=== TEST 3: TLS context is readable during certificate and content phases
--- stream_config
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

        content_by_lua_block {
            local session_depth, active_depth = require("ssl_ctx").depths()
            ngx.say(session_depth, ":", active_depth)
        }
    }
--- stream_server_config
        content_by_lua_block {
            local sock = ngx.socket.tcp()
            assert(sock:connect("unix:$TEST_NGINX_HTML_DIR/ctx-3.sock"))
            assert(sock:sslhandshake(nil, "default.test", false))
            ngx.print(assert(sock:receive("*a")))
            assert(sock:close())
        }
--- stream_response
3:3
--- no_error_log
[error]


=== TEST 4: SNI preserves the original session context
--- stream_config
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

        content_by_lua_block {
            local session_depth, active_depth = require("ssl_ctx").depths()
            ngx.say(session_depth, ":", active_depth)
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

        content_by_lua_block {
            local session_depth, active_depth = require("ssl_ctx").depths()
            ngx.say(session_depth, ":", active_depth)
        }
    }
--- stream_server_config
        content_by_lua_block {
            local sock = ngx.socket.tcp()
            assert(sock:connect("unix:$TEST_NGINX_HTML_DIR/ctx-4.sock"))
            assert(sock:sslhandshake(nil, "selected.test", false))
            ngx.print(assert(sock:receive("*a")))
            assert(sock:close())
        }
--- stream_response
3:7
--- no_error_log
[error]


=== TEST 5: ngx.ssl loads without the optional C symbol
--- stream_server_config
        content_by_lua_block {
            local ffi = require "ffi"
            package.loaded.ffi = setmetatable({
                C = setmetatable({}, {
                    __index = function(_, name)
                        if name == "ngx_stream_lua_ffi_get_req_ssl_ctx" then
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
--- stream_response
true
true: bad request
--- no_error_log
[error]
