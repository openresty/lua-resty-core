# vim:set ft= ts=4 sw=4 et fdm=marker:

BEGIN {
    undef $ENV{TEST_NGINX_USE_STAP};
}

use lib 'lib';
use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

#worker_connections(1014);
master_on();
#log_level('info');

repeat_each(2);

plan tests => repeat_each() * (blocks() * 5);

my $pwd = cwd();

our $HttpConfig = <<_EOC_;
    proxy_cache_path /tmp/proxy_cache_dir keys_zone=cache_one:200m;

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

    init_worker_by_lua_block {
        local base = require "resty.core.base"
        local v
        local typ = (require "ngx.process").type
        for i = 1, 400 do
            v = typ()
        end

        if v == "helper" then
            ngx.log(ngx.WARN, "process type: ", v)
        end
    }
_EOC_

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
            ngx.sleep(0.1)
            local v
            local typ = (require "ngx.process").type
            for i = 1, 200 do
                v = typ()
            end
            ngx.say("type: ", v)
        }
    }
--- request
GET /t
--- response_body
type: worker
--- grep_error_log eval
qr/\[TRACE   \d+ init_worker_by_lua:\d loop\]|\[TRACE   \d+ content_by_lua\(nginx\.conf:\d+\):\d loop\]|process type: \w+/
--- grep_error_log_out eval
[
qr/\[TRACE   \d+ init_worker_by_lua:5 loop\]
\[TRACE   \d+ content_by_lua\(nginx.conf:78\):5 loop\]
/,
qr/\[TRACE   \d+ init_worker_by_lua:5 loop\]
\[TRACE   \d+ content_by_lua\(nginx.conf:78\):5 loop\]
/
]
--- no_error_log
[error]
 -- NYI:
--- skip_nginx: 5: < 1.11.2
--- wait: 0.2
