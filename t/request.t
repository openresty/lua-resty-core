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
    lua_package_path "$pwd/lib/?.lua;;";
    init_by_lua '
        local verbose = false
        if verbose then
            local dump = require "jit.dump"
            dump.on("b", "$Test::Nginx::Util::ErrLogFile")
        else
            local v = require "jit.v"
            v.on("$Test::Nginx::Util::ErrLogFile")
        end

        require "resty.core"
        -- jit.off()
    ';
_EOC_

#no_diff();
#no_long_string();
check_accum_error_log();
run_tests();

__DATA__

=== TEST 1: ngx.req.get_headers
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        set $foo hello;
        content_by_lua '
            local ffi = require "ffi"
            local headers
            for i = 1, 200 do
                headers = ngx.req.get_headers()
            end
            local keys = {}
            for k, _ in pairs(headers) do
                keys[#keys + 1] = k
            end
            table.sort(keys)
            for _, k in ipairs(keys) do
                ngx.say(k, ": ", headers[k])
            end
        ';
    }
--- request
GET /t
--- response_body
bar: bar
baz: baz
connection: Close
foo: foo
host: localhost
--- more_headers
Foo: foo
Bar: bar
Baz: baz
--- error_log eval
qr/\[TRACE   \d+ .*? -> 1\]/
--- no_error_log
[error]
 -- NYI:



=== TEST 2: ngx.req.get_headers (raw)
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        set $foo hello;
        content_by_lua '
            local ffi = require "ffi"
            local headers
            for i = 1, 200 do
                headers = ngx.req.get_headers(100, true)
            end
            local keys = {}
            for k, _ in pairs(headers) do
                keys[#keys + 1] = k
            end
            table.sort(keys)
            for _, k in ipairs(keys) do
                ngx.say(k, ": ", headers[k])
            end
        ';
    }
--- request
GET /t
--- response_body
Bar: bar
Baz: baz
Connection: Close
Foo: foo
Host: localhost
--- more_headers
Foo: foo
Bar: bar
Baz: baz
--- error_log eval
qr/\[TRACE   \d+ .*? -> 1\]/
--- no_error_log
[error]
 -- NYI:



=== TEST 3: ngx.req.get_headers (count is 2)
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        set $foo hello;
        content_by_lua '
            local ffi = require "ffi"
            local headers
            for i = 1, 200 do
                headers = ngx.req.get_headers(2, true)
            end
            local keys = {}
            for k, _ in pairs(headers) do
                keys[#keys + 1] = k
            end
            table.sort(keys)
            for _, k in ipairs(keys) do
                ngx.say(k, ": ", headers[k])
            end
        ';
    }
--- request
GET /t
--- response_body
Connection: Close
Host: localhost
--- more_headers
Foo: foo
Bar: bar
Baz: baz
--- error_log eval
qr/\[TRACE   \d+ "content_by_lua":4 loop\]/
--- no_error_log
[error]
 -- NYI:



=== TEST 4: ngx.req.get_headers (metatable)
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        set $foo hello;
        content_by_lua '
            local ffi = require "ffi"
            local headers, header
            for i = 1, 100 do
                headers = ngx.req.get_headers()
                header = headers["foo_BAR"]
            end
            ngx.say("foo_BAR: ", header)
            local keys = {}
            for k, _ in pairs(headers) do
                keys[#keys + 1] = k
            end
            table.sort(keys)
            for _, k in ipairs(keys) do
                ngx.say(k, ": ", headers[k])
            end
        ';
    }
--- request
GET /t
--- response_body
foo_BAR: foo
baz: baz
connection: Close
foo-bar: foo
host: localhost
--- more_headers
Foo-Bar: foo
Baz: baz
--- error_log eval
qr/\[TRACE   \d+ .*? -> \d\]/
--- no_error_log
[error]
 -- NYI:



=== TEST 5: ngx.req.get_uri_args
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        set $foo hello;
        content_by_lua '
            local ffi = require "ffi"
            local args
            for i = 1, 100 do
                args = ngx.req.get_uri_args()
            end
            if type(args) ~= "table" then
                ngx.say("bad args type found: ", args)
                return
            end
            local keys = {}
            for k, _ in pairs(args) do
                keys[#keys + 1] = k
            end
            table.sort(keys)
            for _, k in ipairs(keys) do
                local v = args[k]
                if type(v) == "table" then
                    ngx.say(k, ": ", table.concat(v, ", "))
                else
                    ngx.say(k, ": ", v)
                end
            end
        ';
    }
--- request
GET /t?a=3%200&foo%20bar=&a=hello&blah
--- response_body
a: 3 0, hello
blah: true
foo bar: 
--- error_log eval
qr/\[TRACE   \d+ .*? -> \d+\]/
--- no_error_log
[error]
 -- NYI:



=== TEST 6: ngx.req.get_uri_args (empty)
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        set $foo hello;
        content_by_lua '
            local ffi = require "ffi"
            local args
            for i = 1, 200 do
                args = ngx.req.get_uri_args()
            end
            if type(args) ~= "table" then
                ngx.say("bad args type found: ", args)
                return
            end
            local keys = {}
            for k, _ in pairs(args) do
                keys[#keys + 1] = k
            end
            table.sort(keys)
            for _, k in ipairs(keys) do
                local v = args[k]
                if type(v) == "table" then
                    ngx.say(k, ": ", table.concat(v, ", "))
                else
                    ngx.say(k, ": ", v)
                end
            end
        ';
    }
--- request
GET /t?
--- response_body
--- error_log eval
qr/\[TRACE   \d+ "content_by_lua":4 loop\]/
--- no_error_log
[error]
 -- NYI:

