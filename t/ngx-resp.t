use lib 'lib';
use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

repeat_each(2);

plan tests => repeat_each() * (blocks() * 3);

my $pwd = cwd();

add_block_preprocessor(sub {
    my $block = shift;

    my $http_config = $block->http_config || '';
    my $init_by_lua_block = $block->init_by_lua_block || 'require "resty.core"';

    $http_config .= <<_EOC_;

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
    }
_EOC_

    $block->set_value("http_config", $http_config);

    if (!defined $block->error_log) {
        $block->set_value("no_error_log", "[error]");
    }

    if (!defined $block->request) {
        $block->set_value("request", "GET /t");
    }

});

check_accum_error_log();
run_tests();

__DATA__

=== TEST 1: ngx.resp.add_header (single value)
--- config
    location = /t {
        set $foo hello;
        content_by_lua_block {
            local ngx_resp = require "ngx.resp"
            ngx_resp.add_header("Foo", "bar")
            ngx_resp.add_header("Foo", 2)
            ngx.say("Foo: ", table.concat(ngx.header["Foo"], ", "))
        }
    }
--- response_body
Foo: bar, 2



=== TEST 2: ngx.resp.add_header (nil)
--- config
    location = /t {
        content_by_lua_block {
            local ngx_resp = require "ngx.resp"
            local ok, err = pcall(ngx_resp.add_header, "Foo")
            if not ok then
                ngx.say(err)
            else
                ngx.say('ok')
            end
        }
    }
--- response_body
invalid header value



=== TEST 3: ngx.resp.add_header (multi-value)
--- config
    location = /t {
        set $foo hello;
        content_by_lua_block {
            local ngx_resp = require "ngx.resp"
            ngx_resp.add_header('Foo', {'bar', 'baz'})
            local v = ngx.header["Foo"]
            ngx.say("Foo: ", table.concat(ngx.header["Foo"], ", "))
        }
    }
--- response_body
Foo: bar, baz



=== TEST 4: ngx.resp.add_header (append header)
--- config
    location = /t {
        set $foo hello;
        content_by_lua_block {
            local ngx_resp = require "ngx.resp"
            ngx.header["fruit"] = "apple"
            ngx_resp.add_header("fruit", "banana")
            ngx_resp.add_header("fruit", "cherry")
            ngx.say("fruit: ", table.concat(ngx.header["fruit"], ", "))
        }
    }
--- response_body
fruit: apple, banana, cherry



=== TEST 5: ngx.resp.add_header (override builtin header)
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        set $foo hello;
        content_by_lua_block {
            local ngx_resp = require "ngx.resp"
            ngx_resp.add_header("Date", "now")
            ngx.say("Date: ", ngx.header["Date"])
        }
    }
--- response_body
Date: now
