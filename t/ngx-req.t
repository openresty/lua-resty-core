use lib 'lib';
use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

repeat_each(2);

plan tests => repeat_each() * (blocks() * 3 + 2);

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

no_long_string();
check_accum_error_log();
run_tests();

__DATA__

=== TEST 1: ngx.req.add_header (jitted)
--- config
    location = /t {
        content_by_lua_block {
            local ngx_req = require "ngx.req"
            for i = 1, 500 do
                ngx_req.add_header("Foo", "bar")
            end
        }
    }
--- error_log eval
qr/\[TRACE\s+\d+ content_by_lua\(nginx\.conf:\d+\):3 loop\]/
--- no_error_log
[error]
bad argument type
stitch



=== TEST 2: ngx.req.add_header (single value)
--- config
    location = /t {
        content_by_lua_block {
            local ngx_req = require "ngx.req"
            ngx.req.set_header("Foo", "bar")
            ngx_req.add_header("Foo", "baz")
            ngx_req.add_header("Foo", 2)
            ngx.say("Foo: ", table.concat(ngx.req.get_headers()["Foo"], ", "))
        }
    }
--- response_body
Foo: bar, baz, 2



=== TEST 3: ngx.req.add_header (invalid header value: nil, {})
--- config
    location = /t {
        content_by_lua_block {
            local ngx_req = require "ngx.req"
            local function check_invalid_header_value(...)
                local ok, err = pcall(ngx_req.add_header, "Foo", ...)
                if not ok then
                    ngx.say(err)
                else
                    ngx.say('ok')
                end
            end

            check_invalid_header_value()
            check_invalid_header_value(nil)
            check_invalid_header_value({})
        }
    }
--- response_body
invalid header value
invalid header value
invalid header value



=== TEST 4: ngx.resp.add_header (override builtin header)
--- config
    location = /t {
        content_by_lua_block {
            local ngx_req = require "ngx.req"
            ngx_req.add_header("User-Agent", "Mozilla/5.0 (Android; Mobile; rv:13.0) Gecko/13.0 Firefox/13.0")
            ngx.say("UA: ", ngx.var.http_user_agent)
        }
    }
--- response_body
UA: Mozilla/5.0 (Android; Mobile; rv:13.0) Gecko/13.0 Firefox/13.0



=== TEST 5: ngx.req.add_header (multiple value)
--- config
    location = /t {
        content_by_lua_block {
            local ngx_req = require "ngx.req"
            ngx.req.set_header("Foo", "bar")
            ngx_req.add_header("Foo", {"baz", 2})
            ngx.say("Foo: ", table.concat(ngx.req.get_headers()["Foo"], ", "))
        }
    }
--- response_body
Foo: bar, baz, 2



=== TEST 5: ngx.req.add_header (multiple value)
--- config
    location = /t {
        content_by_lua_block {
            local ngx_req = require "ngx.req"
            ngx.req.set_header("Foo", "bar")
            ngx_req.add_header("Foo", {"baz", 2})
            ngx.say("Foo: ", table.concat(ngx.req.get_headers()["Foo"], ", "))
        }
    }
--- response_body
Foo: bar, baz, 2



=== TEST 6: added header is inherited by the subrequest
--- config
    location = /sub {
        content_by_lua_block {
            ngx.say("Foo: ", table.concat(ngx.req.get_headers()["Foo"], ", "))
        }
    }

    location = /t {
        content_by_lua_block {
            local ngx_req = require "ngx.req"
            ngx.req.set_header("Foo", "bar")
            ngx_req.add_header("Foo", {"baz", 2})
            res = ngx.location.capture("/sub")
            ngx.print(res.body)
        }
    }
--- response_body
Foo: bar, baz, 2



=== TEST 7: ngx.req.add_header ('')
--- config
    location = /t {
        content_by_lua_block {
            local ngx_req = require "ngx.req"
            ngx.req.set_header("Foo", "bar")
            ngx_req.add_header("Foo", '')
            ngx.say("Foo: [", table.concat(ngx.req.get_headers()["Foo"], ", "), ']')
        }
    }
--- response_body
Foo: [bar, ]
