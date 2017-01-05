# vim:set ft= ts=4 sw=4 et fdm=marker:
use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

repeat_each(2);

plan tests => repeat_each() * (blocks() * 4 + 3);

my $pwd = cwd();

our $HttpConfig = <<_EOC_;
    lua_package_path "$pwd/lib/?.lua;;";
    init_by_lua_block {
        local v = require "jit.v"
        v.on("$Test::Nginx::Util::ErrLogFile")

        require "resty.core"
    }
_EOC_

check_accum_error_log();
run_tests();

__DATA__

=== TEST 1: get_phase in init_by_lua
--- http_config
    lua_package_path "$pwd/lib/?.lua;;";
    init_by_lua_block {
        local v = require "jit.v"
        v.on("$Test::Nginx::Util::ErrLogFile")

        require "resty.core"

        phase = ngx.get_phase()
    }
--- config
    location /lua {
        content_by_lua_block {
            ngx.say(phase)
        }
    }
--- request
GET /lua
--- response_body
init



=== TEST 2: get_phase in set_by_lua
--- http_config eval: $::HttpConfig
--- config
    set_by_lua_block $phase {
        local phase
        for i = 1, 100 do
            phase = ngx.get_phase()
        end
        return phase
    }
    location /lua {
        content_by_lua_block {
            ngx.say(ngx.var.phase)
        }
    }
--- request
GET /lua
--- response_body
set
--- no_error_log
[error]
 -- NYI:
--- error_log eval
qr/\[TRACE\s+\d+\s+set_by_lua:\d+ loop\]/



=== TEST 3: get_phase in rewrite_by_lua
--- http_config eval: $::HttpConfig
--- config
    location /lua {
        rewrite_by_lua_block {
            local phase
            for i = 1, 100 do
                phase = ngx.get_phase()
            end
            ngx.say(phase)
            ngx.exit(200)
        }
    }
--- request
GET /lua
--- response_body
rewrite
--- no_error_log
[error]
 -- NYI:
--- error_log eval
qr/\[TRACE\s+\d+\s+rewrite_by_lua\(nginx\.conf:\d+\):3 loop\]/



=== TEST 4: get_phase in access_by_lua
--- http_config eval: $::HttpConfig
--- config
    location /lua {
        access_by_lua_block {
            local phase
            for i = 1, 100 do
                phase = ngx.get_phase()
            end
            ngx.say(phase)
            ngx.exit(200)
        }
    }
--- request
GET /lua
--- response_body
access
--- no_error_log
[error]
 -- NYI:
--- error_log eval
qr/\[TRACE\s+\d+\s+access_by_lua\(nginx\.conf:\d+\):3 loop\]/



=== TEST 5: get_phase in content_by_lua
--- http_config eval: $::HttpConfig
--- config
    location /lua {
        content_by_lua_block {
            local phase
            for i = 1, 100 do
                phase = ngx.get_phase()
            end
            ngx.say(phase)
        }
    }
--- request
GET /lua
--- response_body
content
--- no_error_log
[error]
 -- NYI:
--- error_log eval
qr/\[TRACE\s+\d+\s+content_by_lua\(nginx\.conf:\d+\):3 loop\]/



=== TEST 6: get_phase in header_filter_by_lua
--- http_config eval: $::HttpConfig
--- config
    location /lua {
        echo "OK";
        header_filter_by_lua_block {
            local phase
            for i = 1, 100 do
                phase = ngx.get_phase()
            end
            ngx.header.Phase = phase
        }
    }
--- request
GET /lua
--- response_header
Phase: header_filter
--- no_error_log
[error]
 -- NYI:
--- error_log eval
qr/\[TRACE\s+\d+\s+header_filter_by_lua:3 loop\]/



=== TEST 7: get_phase in body_filter_by_lua
--- http_config eval: $::HttpConfig
--- config
    location /lua {
        content_by_lua_block {
            ngx.exit(200)
        }
        body_filter_by_lua_block {
            local phase
            for i = 1, 100 do
                phase = ngx.get_phase()
            end
            ngx.arg[1] = phase
        }
    }
--- request
GET /lua
--- response_body chop
body_filter
--- no_error_log
[error]
 -- NYI:
--- error_log eval
qr/\[TRACE\s+\d+\s+body_filter_by_lua:3 loop\]/



=== TEST 8: get_phase in log_by_lua
--- http_config eval: $::HttpConfig
--- config
    location /lua {
        echo "OK";
        log_by_lua_block {
            local phase
            for i = 1, 100 do
                phase = ngx.get_phase()
            end
            ngx.log(ngx.INFO, phase)
        }
    }
--- request
GET /lua
--- error_log
log
--- no_error_log
[error]
 -- NYI:



=== TEST 9: get_phase in ngx.timer callback
--- http_config eval: $::HttpConfig
--- config
    location /lua {
        echo "OK";
        log_by_lua_block {
            local function f()
                local phase
                for i = 1, 100 do
                    phase = ngx.get_phase()
                end
                ngx.log(ngx.WARN, "current phase: ", phase)
            end
            local ok, err = ngx.timer.at(0, f)
            if not ok then
                ngx.log(ngx.ERR, "failed to add timer: ", err)
            end
        }
    }
--- request
GET /lua
--- no_error_log
[error]
--- error_log
current phase: timer
--- no_error_log
[error]
 -- NYI:



=== TEST 10: get_phase in init_worker_by_lua
--- http_config eval: $::HttpConfig
--- http_config
    init_worker_by_lua_block { phase = ngx.get_phase()}
--- config
    location /lua {
        content_by_lua_block {
            ngx.say(phase)
        }
    }
--- request
GET /lua
--- response_body
init_worker
--- no_error_log
[error]
 -- NYI:
