# vim:set ft= ts=4 sw=4 et fdm=marker:
use lib 'lib';
use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

master_on();
workers(5);

repeat_each(3);

plan tests => repeat_each() * (blocks() * 3);

our $pwd = cwd();

our $HttpConfig = <<_EOC_;
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

check_accum_error_log();
run_tests();

__DATA__

=== TEST 1: math.random defaults to identical seeds
--- http_config eval
qq{
    lua_shared_dict randoms 1m;

    init_worker_by_lua_block {
        local dict = ngx.shared.randoms
        local u = math.random()
        assert(dict:add(u, true))
    }
}
--- config
    location = /t {
        return 200;
    }
--- request
GET /t
--- response_body

--- error_log eval
qr/\[error\] .*? init_worker_by_lua:\d+: exists/



=== TEST 2: ngx.math.randomseed uses truly unique seeds
--- http_config eval
qq{
    $::HttpConfig

    lua_shared_dict randoms 1m;

    init_worker_by_lua_block {
        local ngx_math = require "ngx.math"

        ngx_math.randomseed()

        local dict = ngx.shared.randoms
        local u = math.random()
        assert(dict:add(u, true))
    }
}
--- config
    location = /t {
        return 200;
    }
--- request
GET /t
--- response_body

--- no_error_log
[error]



=== TEST 3: ngx.math.randomseed returns used seed
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local ngx_math = require "ngx.math"

            ngx.say(ngx_math.randomseed())
        }
    }
--- request
GET /t
--- response_body_like
\d+
--- no_error_log
[error]



=== TEST 4: ngx.math.randomseed disabled in init context
--- http_config eval
qq{
    lua_package_path "$::pwd/lib/?.lua;../lua-resty-lrucache/lib/?.lua;;";

    init_by_lua_block {
        local ngx_math = require "ngx.math"

        local ok, err = pcall(ngx_math.randomseed)
        if not ok then
            ngx.log(ngx.NOTICE, err)
        end
    }
}
--- config
    location = /t {
        return 200;
    }
--- request
GET /t
--- response_body

--- error_log eval
qr/\[notice\] .*? init_by_lua:\d+: API disabled in the current context/



=== TEST 5: ngx.math.randomseed does not nop math.randomseed (dangerous)
--- http_config eval
qq{
    $::HttpConfig

    lua_shared_dict randoms 1m;

    init_worker_by_lua_block {
        local ngx_math = require "ngx.math"

        ngx_math.randomseed()

        math.randomseed(os.time())

        local dict = ngx.shared.randoms
        local u = math.random()
        assert(dict:add(u, true))
    }
}
--- config
    location = /t {
        return 200;
    }
--- request
GET /t
--- response_body

--- error_log eval
qr/\[error\] .*? init_worker_by_lua:\d+: exists/



=== TEST 6: ngx.math.randomseed can nop math.randomseed
--- http_config eval
qq{
    $::HttpConfig

    lua_shared_dict randoms 1m;

    init_worker_by_lua_block {
        local ngx_math = require "ngx.math"

        ngx_math.randomseed(true)

        math.randomseed(os.time())

        local dict = ngx.shared.randoms
        local u = math.random()
        assert(dict:add(u, true))
    }
}
--- config
    location = /t {
        return 200;
    }
--- request
GET /t
--- response_body

--- no_error_log
[error]



=== TEST 7: ngx.math.randomseed JITs
--- SKIP: ngx.get_phase NYI, see lua-resty-core#78
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local ngx_math = require "ngx.math"

            for i = 1, 100 do
                ngx_math.randomseed()
            end
        }
    }
--- request
GET /t
--- response_body

--- no_error_log
[error]
 -- NYI:
--- error_log eval
qr/\[TRACE\s+\d+\s+content_by_lua\(nginx\.conf:\d+\):2 loop\]/
