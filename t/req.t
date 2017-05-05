# vim:set ft= ts=4 sw=4 et fdm=marker:
use lib 'lib';
use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

#worker_connections(1014);
#master_process_enabled(1);
#log_level('warn');

repeat_each(2);

plan tests => repeat_each() * blocks() * 3;

my $pwd = cwd();

our $HttpConfig = <<_EOC_;
    lua_package_path "$pwd/lib/?.lua;../lua-resty-lrucache/lib/?.lua;;";
    init_by_lua_block {
        -- local verbose = true
        local verbose = false
        local outfile = "$Test::Nginx::Util::ErrLogFile"
        -- local outfile = "/tmp/v.log"
        if verbose then
            local dump = require "jit.dump"
            dump.on(nil, outfile)
        else
            local v = require "jit.v"
            v.on(outfile)
        end

        require "resty.core"
        -- jit.opt.start("hotloop=1")
        -- jit.opt.start("loopunroll=1000000")
        -- jit.off()
    }
_EOC_

no_diff();
no_long_string();
check_accum_error_log();
run_tests();

__DATA__

=== TEST 1: ngx_req.get_uri_ext
--- http_config eval: $::HttpConfig
--- config
    location /test.m3u8 {
        content_by_lua_block {
            local ngx_req = require "ngx.req"
            local ext = ngx_req.get_uri_ext()
            ngx.say(ext)
        }
    }
--- request
GET /test.m3u8
--- response_body
m3u8
--- no_error_log
[error]



=== TEST 2: ngx_req.get_uri_ext (uri has no extension)
--- http_config eval: $::HttpConfig
--- config
location /test {
        content_by_lua_block {
            local ngx_req = require "ngx.req"
            local ext = ngx_req.get_uri_ext()
            ngx.say(ext)
        }
    }
--- request
GET /test
--- response_body eval
"\n"
--- no_error_log
[error]



=== TEST 3: ngx_req.get_uri_ext (rewrite uri)
--- http_config eval: $::HttpConfig
--- config
    location = /test.m3u8 {
        content_by_lua_block {
            local ngx_req = require "ngx.req"
            ngx.req.set_uri("/test.ts")
            local ext = ngx_req.get_uri_ext()
            ngx.say(ext)
        }
    }
--- request
GET /test.m3u8
--- response_body
ts
--- no_error_log
[error]



=== TEST 4: ngx_req.get_uri_ext (ext_len is larger)
--- http_config eval: $::HttpConfig
--- config
    location = /test.m3u8 {
        content_by_lua_block {
            local ngx_req = require "ngx.req"
            local ext = ngx_req.get_uri_ext(10)
            ngx.say(ext)
        }
    }
--- request
GET /test.m3u8
--- response_body
m3u8
--- no_error_log
[error]



=== TEST 5: ngx_req.get_uri_ext (ext_len is lower)
--- http_config eval: $::HttpConfig
--- config
    location = /test.m3u8 {
        content_by_lua_block {
            local ngx_req = require "ngx.req"
            local ext = ngx_req.get_uri_ext(2)
            ngx.say(ext)
        }
    }
--- request
GET /test.m3u8
--- response_body
m3
--- no_error_log
[error]



=== TEST 6: ngx_req.get_uri_ext (.tar.gz)
--- http_config eval: $::HttpConfig
--- config
    location = /test.tar.gz {
        content_by_lua_block {
            local ngx_req = require "ngx.req"
            local ext = ngx_req.get_uri_ext()
            ngx.say(ext)
        }
    }
--- request
GET /test.tar.gz
--- response_body
gz
--- no_error_log
[error]



=== TEST 7: ngx_req.get_uri_ext (.html)
--- http_config eval: $::HttpConfig
--- config
    location = /test.html {
        content_by_lua_block {
            local ngx_req = require "ngx.req"
            local ext = ngx_req.get_uri_ext()
            ngx.say(ext)
        }
    }
--- request
GET /test.html
--- response_body
html
--- no_error_log
[error]
