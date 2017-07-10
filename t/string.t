# vim:set ft=nginx ts=4 sw=4 et fdm=marker:
use lib 'lib';
use Test::Nginx::Socket::Lua 'no_plan';
use Cwd qw(cwd);

#worker_connections(1014);
#master_process_enabled(1);
#log_level('warn');

repeat_each(2);

my $pwd = cwd();

our $HttpConfig = <<_EOC_;
    lua_shared_dict dogs 1m;
    lua_package_path "$pwd/lib/?.lua;../lua-resty-lrucache/lib/?.lua;;";
    init_by_lua_block {
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
    }
_EOC_

#no_diff();
#no_long_string();
check_accum_error_log();
run_tests();

__DATA__

=== TEST 1 ngx.decode_args (sanity)
--- http_config eval: $::HttpConfig
--- config
    location /lua {
        content_by_lua '
            local args = "a=bar&b=foo"
            args = ngx.decode_args(args)
            ngx.say("a = ", args.a)
            ngx.say("b = ", args.b)
        ';
    }
--- request
GET /lua
--- response_body
a = bar
b = foo



=== TEST 2: ngx.decode_args (multi-value)
--- http_config eval: $::HttpConfig
--- config
    location /lua {
        content_by_lua '
            local args = "a=bar&b=foo&a=baz"
            args = ngx.decode_args(args)
            ngx.say("a = ", table.concat(args.a, ", "))
            ngx.say("b = ", args.b)
        ';
    }
--- request
GET /lua
--- response_body
a = bar, baz
b = foo



=== TEST 3: ngx.decode_args (empty string)
--- http_config eval: $::HttpConfig
--- config
    location /lua {
        content_by_lua '
            local args = ""
            args = ngx.decode_args(args)
            ngx.say("n = ", #args)
        ';
    }
--- request
GET /lua
--- response_body
n = 0



=== TEST 4: ngx.decode_args (boolean args)
--- http_config eval: $::HttpConfig
--- config
    location /lua {
        content_by_lua '
            local args = "a&b"
            args = ngx.decode_args(args)
            ngx.say("a = ", args.a)
            ngx.say("b = ", args.b)
        ';
    }
--- request
GET /lua
--- response_body
a = true
b = true



=== TEST 5: ngx.decode_args (empty value args)
--- config
    location /lua {
        content_by_lua '
            local args = "a=&b="
            args = ngx.decode_args(args)
            ngx.say("a = ", args.a)
            ngx.say("b = ", args.b)
        ';
    }
--- request
GET /lua
--- response_body
a = 
b = 



=== TEST 6: ngx.decode_args (max_args = 1)
--- http_config eval: $::HttpConfig
--- config
    location /lua {
        content_by_lua '
            local args = "a=bar&b=foo"
            args = ngx.decode_args(args, 1)
            ngx.say("a = ", args.a)
            ngx.say("b = ", args.b)
        ';
    }
--- request
GET /lua
--- response_body
a = bar
b = nil



=== TEST 7: ngx.decode_args (max_args = -1)
--- http_config eval: $::HttpConfig
--- config
    location /lua {
        content_by_lua '
            local args = "a=bar&b=foo"
            args = ngx.decode_args(args, -1)
            ngx.say("a = ", args.a)
            ngx.say("b = ", args.b)
        ';
    }
--- request
GET /lua
--- response_body
a = bar
b = foo



=== TEST 8: ngx.decode_args should not modify lua strings in place
--- http_config eval: $::HttpConfig
--- config
    location /lua {
        content_by_lua '
            local s = "f+f=bar&B=foo"
            args = ngx.decode_args(s)
            local arr = {}
            for k, v in pairs(args) do
                table.insert(arr, k)
            end
            table.sort(arr)
            for i, k in ipairs(arr) do
                ngx.say("key: ", k)
            end
            ngx.say("s = ", s)
        ';
    }
--- request
GET /lua
--- response_body
key: B
key: f f
s = f+f=bar&B=foo
--- no_error_log
[error]



=== TEST 9: ngx.decode_args should not modify lua strings in place (sample from Xu Jian)
--- http_config eval: $::HttpConfig
--- config
    lua_need_request_body on;
    location /t {
        content_by_lua '
            function split(s, delimiter)
                local result = {}
                local from = 1
                local delim_from, delim_to = string.find(s, delimiter, from)
                while delim_from do
                    table.insert(result, string.sub(s, from, delim_from - 1))
                    from = delim_to + 1
                    delim_from, delim_to = string.find(s, delimiter, from)
                end
                table.insert(result, string.sub(s, from))
                return result
            end

            local post_data = ngx.req.get_body_data()

            local commands = split(post_data, "||")
            for _, command in pairs(commands) do
                --command = ngx.unescape_uri(command)
                local request_args = ngx.decode_args(command, 0)
                local arr = {}
                for k, v in pairs(request_args) do
                    table.insert(arr, k)
                end
                table.sort(arr)
                for i, k in ipairs(arr) do
                    ngx.say(k, ": ", request_args[k])
                end
                ngx.say(" ===============")
            end
        ';
    }
--- request
POST /t
method=zadd&key=User%3A1227713%3Alikes%3Atwitters&arg1=1356514698&arg2=780984852||method=zadd&key=User%3A1227713%3Alikes%3Atwitters&arg1=1356514698&arg2=780984852||method=zadd&key=User%3A1227713%3Alikes%3Atwitters&arg1=1356514698&arg2=780984852
--- response_body
arg1: 1356514698
arg2: 780984852
key: User:1227713:likes:twitters
method: zadd
 ===============
arg1: 1356514698
arg2: 780984852
key: User:1227713:likes:twitters
method: zadd
 ===============
arg1: 1356514698
arg2: 780984852
key: User:1227713:likes:twitters
method: zadd
 ===============
--- no_error_log
[error]
