# vim:set ft= ts=4 sw=4 et fdm=marker:
use lib 'lib';
use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

#worker_connections(1014);
master_process_enabled(1);
#log_level('error');

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
    }

    init_worker_by_lua_block {
        local v
        local typ = (require "ngx.process").type
        for i = 1, 400 do
            v = typ()
        end

        local type_name = (require "ngx.process").type_name
        ngx.log(ngx.WARN, "process type: ", type_name(v))
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
            local v
            local typ = (require "ngx.process").type
            for i = 1, 400 do
                v = typ()
            end

            local type_name = (require "ngx.process").type_name
            ngx.say("process type: ", type_name(v))
        }
    }
--- request
GET /t
--- response_body
process type: worker process
--- grep_error_log eval
qr/\[TRACE   \d+ init_worker_by_lua:4 loop\]|\[TRACE   \d+ content_by_lua\(nginx\.conf:\d+\):4 loop\]|init_worker_by_lua:\d: process type: \w+/
--- grep_error_log_out eval
[
"[TRACE   1 init_worker_by_lua:4 loop]
[TRACE   1 content_by_lua(nginx.conf:75):4 loop]
init_worker_by_lua:9: process type: worker
",
"[TRACE   1 init_worker_by_lua:4 loop]
[TRACE   1 content_by_lua(nginx.conf:75):4 loop]
init_worker_by_lua:9: process type: worker
"
]
--- no_error_log
[error]
 -- NYI:
--- skip_nginx: 5: < 1.11.2
