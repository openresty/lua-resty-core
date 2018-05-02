# vim:set ft= ts=4 sw=4 et fdm=marker:
use lib 'lib';
use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

#worker_connections(1014);
#master_process_enabled(1);
log_level('warn');

#repeat_each(120);
repeat_each(2);

plan tests => repeat_each() * (blocks() * 5 - 6);

my $pwd = cwd();

our $HttpConfig = <<_EOC_;
    lua_package_path "$pwd/lib/?.lua;\$prefix/html/?.lua;../lua-resty-lrucache/lib/?.lua;;";
    init_by_lua_block {
        local verbose = false
        if verbose then
            local dump = require "jit.dump"
            dump.on(nil, "$Test::Nginx::Util::ErrLogFile")
        else
            local v = require "jit.v"
            v.on("$Test::Nginx::Util::ErrLogFile")
        end

        require "resty.core"
        -- jit.off()
    }
_EOC_

#no_diff();
#no_long_string();
check_accum_error_log();
run_tests();

__DATA__

=== TEST 1: ngx.is_subrequest
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        return 201;
        header_filter_by_lua_block {
            local rc
            for i = 1, 100 do
                rc = ngx.is_subrequest
            end
            ngx.log(ngx.WARN, "is subrequest: ", rc)
        }
    }
--- request
GET /t
--- response_body
--- error_code: 201
--- no_error_log
[error]
 -- NYI:
 bad argument
--- error_log eval
["is subrequest: false,",
qr/\[TRACE\s+\d+\s+header_filter_by_lua:3 loop\]/
]



=== TEST 2: ngx.headers_sent (false)
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local rc
            for i = 1, 100 do
                rc = ngx.headers_sent
            end
            ngx.say("headers sent: ", rc)
        }
    }
--- request
GET /t
--- response_body
headers sent: false
--- no_error_log
[error]
 -- NYI:
 bad argument
--- error_log eval
qr/\[TRACE\s+\d+\s+content_by_lua\(nginx\.conf:\d+\):3 loop\]/



=== TEST 3: ngx.headers_sent (true)
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            ngx.send_headers()
            local rc
            for i = 1, 100 do
                rc = ngx.headers_sent
            end
            ngx.say("headers sent: ", rc)
        }
    }
--- request
GET /t
--- response_body
headers sent: true
--- no_error_log
[error]
 -- NYI:
 bad argument
--- error_log eval
qr/\[TRACE\s+\d+\s+content_by_lua\(nginx\.conf:\d+\):4 loop\]/



=== TEST 4: base.check_subsystem
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local base = require "resty.core.base"
            base.allows_subsystem('http', 'stream')
            base.allows_subsystem('http')

            ngx.say("ok")
        }
    }
--- request
GET /t
--- response_body
ok
--- no_error_log
[error]
 -- NYI:
 bad argument



=== TEST 5: base.check_subsystem with non-http subsystem
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local base = require "resty.core.base"
            base.allows_subsystem('stream')

            ngx.say("ok")
        }
    }
--- request
GET /t
--- error_code: 500
--- no_error_log
 -- NYI:
 bad argument
--- error_log
unsupported subsystem: http



=== TEST 6: not internal request
--- http_config eval: $::HttpConfig
--- config
    location /test {
        rewrite ^/test$ /lua last;
    }
    location /lua {
        content_by_lua_block {
            if ngx.req.is_internal() then
                ngx.say("internal")
            else
                ngx.say("not internal")
            end
        }
    }
--- request
GET /lua
--- response_body
not internal



=== TEST 7: internal request
--- http_config eval: $::HttpConfig
--- config
    location /test {
        rewrite ^/test$ /lua last;
    }
    location /lua {
        content_by_lua_block {
            if ngx.req.is_internal() then
                ngx.say("internal")
            else
                ngx.say("not internal")
            end
        }
    }
--- request
GET /test
--- response_body
internal



=== TEST 8: bad context
--- http_config eval: $::HttpConfig
--- config
    location /lua {
        content_by_lua_block {
            local function test()
                local ok, err = pcall(ngx.req.is_internal)
                package.loaded.bad_context = {ok, err}
            end

            ngx.timer.at(0, test)
            ngx.sleep(0.02)

            local ctx = package.loaded.bad_context
            ngx.say(ctx[1])
            local i = string.find(ctx[2], "API disabled in the current context")
            ngx.say(i > 1)
        }
    }
--- request
GET /lua
--- response_body
false
true
