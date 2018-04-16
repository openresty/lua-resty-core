# vim:set ft= ts=4 sw=4 et fdm=marker:
use lib 'lib';
use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

#worker_connections(1014);
#master_process_enabled(1);
#log_level('warn');

repeat_each(2);

plan tests => repeat_each() * (blocks() * 5);

my $pwd = cwd();

our $HttpConfig = <<_EOC_;
    lua_shared_dict dogs 1m;
    lua_package_path "$pwd/lib/?.lua;../lua-resty-lrucache/lib/?.lua;;";
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

=== TEST 1: get normal var
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        set $foo hello;
        content_by_lua_block {
            local ffi = require "ffi"
            local val
            for i = 1, 100 do
                val = ngx.var.foo
            end
            ngx.say("value: ", val)
        }
    }
--- request
GET /t
--- response_body
value: hello
--- error_log eval
qr/\[TRACE   \d+ content_by_lua\(nginx\.conf:\d+\):4 loop\]/
--- no_error_log
[error]
 -- NYI: (?!return to lower frame)



=== TEST 2: get normal var (case)
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        set $foo hello;
        content_by_lua_block {
            local ffi = require "ffi"
            local val
            for i = 1, 100 do
                val = ngx.var.FOO
            end
            ngx.say("value: ", val)
        }
    }
--- request
GET /t
--- response_body
value: hello
--- error_log eval
qr/\[TRACE   \d+ content_by_lua\(nginx\.conf:\d+\):4 loop\]/
--- no_error_log
[error]
 -- NYI: (?!return to lower frame)



=== TEST 3: get capturing var (bad)
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        set $foo hello;
        content_by_lua_block {
            local ffi = require "ffi"
            local val
            for i = 1, 100 do
                val = ngx.var[0]
            end
            ngx.say("value: ", val)
        }
    }
--- request
GET /t
--- response_body
value: nil
--- error_log eval
qr/\[TRACE   \d+ content_by_lua\(nginx\.conf:\d+\):4 loop\]/
--- no_error_log
[error]
 -- NYI:



=== TEST 4: get capturing var
--- http_config eval: $::HttpConfig
--- config
    location ~ '^(/t)' {
        set $foo hello;
        content_by_lua_block {
            local ffi = require "ffi"
            local val
            for i = 1, 100 do
                val = ngx.var[1]
            end
            ngx.say("value: ", val)
        }
    }
--- request
GET /t
--- response_body
value: /t
--- error_log eval
qr/\[TRACE   \d+ content_by_lua\(nginx\.conf:\d+\):4 loop\]/
--- no_error_log
[error]
 -- NYI: (?!return to lower frame)



=== TEST 5: set normal var (string value)
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        set $foo hello;
        content_by_lua_block {
            local ffi = require "ffi"
            local val = "hello"
            for i = 1, 100 do
                ngx.var.foo = val
            end
            ngx.say("value: ", val)
        }
    }
--- request
GET /t
--- response_body
value: hello
--- error_log eval
qr/\[TRACE   \d+ content_by_lua\(nginx\.conf:\d+\):4 loop\]/
--- no_error_log
[error]
 -- NYI:



=== TEST 6: set normal var (nil value)
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        set $foo hello;
        content_by_lua_block {
            local ffi = require "ffi"
            for i = 1, 100 do
                ngx.var.foo = nil
            end
            ngx.say("value: ", ngx.var.foo)
        }
    }
--- request
GET /t
--- response_body
value: nil
--- error_log eval
qr/\[TRACE   \d+ content_by_lua\(nginx\.conf:\d+\):3 loop\]/
--- no_error_log
[error]
 -- NYI:



=== TEST 7: set normal var (number value)
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        set $foo hello;
        content_by_lua_block {
            local ffi = require "ffi"
            for i = 1, 100 do
                ngx.var.foo = i
            end
            ngx.say("value: ", ngx.var.foo)
        }
    }
--- request
GET /t
--- response_body
value: 100
--- error_log eval
qr/\[TRACE   \d+ content_by_lua\(nginx\.conf:\d+\):3 loop\]/
--- no_error_log
[error]
 -- NYI:



=== TEST 8: error buffer overread
--- http_config eval: $::HttpConfig
--- config
    location = /test {
        content_by_lua_block {
            local ok1, err1 = pcall(function () ngx.var.foo = 32; end)
            local ok2, err2 = pcall(function () ngx.var.server_port = 32; end)
            assert(not ok1)
            ngx.say(err1)
            assert(not ok2)
            ngx.say(err2)
        }
    }
--- request
GET /test
--- response_body_like
.+/var\.lua:\d+: variable "foo" not found for writing; maybe it is a built-in variable that is not changeable or you forgot to use "set \$foo '';" in the config file to define it first
.+/var\.lua:\d+: variable "server_port" not changeable
--- no_error_log
[error]
[alert]
 -- NYI:
