# vim:set ft= ts=4 sw=4 et fdm=marker:

BEGIN {
    undef $ENV{TEST_NGINX_USE_STAP};
}

use lib 'lib';
use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

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
            dump.on("b", "$Test::Nginx::Util::ErrLogFile")
        else
            local v = require "jit.v"
            v.on("$Test::Nginx::Util::ErrLogFile")
        end

        require "resty.core"
        -- jit.off()

        local v
        local typ = (require "ngx.process").type
        for i = 1, 400 do
            v = typ()
        end

        package.loaded.process_type = v
    }

    init_worker_by_lua_block {
        local v
        local typ = (require "ngx.process").type
        for i = 1, 400 do
            v = typ()
        end

        ngx.log(ngx.WARN, "process type in init_by_lua*: ",
                package.loaded.process_type)
        ngx.log(ngx.WARN, "process type: ", v)
    }
_EOC_

#worker_connections(1014);
#log_level('error');

#no_diff();
#no_long_string();
check_accum_error_log();
run_tests();

__DATA__

=== TEST 1: sanity
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local v
            local typ = (require "ngx.process").type
            for i = 1, 400 do
                v = typ()
            end

            ngx.say("process type: ", v)
        }
    }
--- request
GET /t
--- response_body
process type: single
--- grep_error_log eval
qr/\[TRACE\s+\d+ init_by_lua:\d+ loop\]|\[TRACE\s+\d+ init_worker_by_lua:\d loop\]|\[TRACE\s+\d+ content_by_lua\(nginx\.conf:\d+\):\d loop\]|process type in init_by_lua\*: \w+|init_worker_by_lua:\d+: process type: \w+/
--- grep_error_log_out eval
[
qr/\[TRACE\s+\d+ init_by_lua:16 loop\]
\[TRACE\s+\d+ init_worker_by_lua:4 loop\]
\[TRACE\s+\d+ content_by_lua\(nginx.conf:83\):4 loop\]
process type in init_by_lua\*: single
init_worker_by_lua:10: process type: single
/,
qr/\[TRACE\s+\d+ init_by_lua:16 loop\]
\[TRACE\s+\d+ init_worker_by_lua:4 loop\]
\[TRACE\s+\d+ content_by_lua\(nginx.conf:83\):4 loop\]
process type in init_by_lua\*: single
init_worker_by_lua:10: process type: single
/
]
--- no_error_log
[error]
 -- NYI:
--- skip_nginx: 5: < 1.11.2
