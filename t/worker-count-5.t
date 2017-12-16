# vim:set ft= ts=4 sw=4 et fdm=marker:
use lib 'lib';
use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

workers(5);
#worker_connections(1014);
#master_process_enabled(1);
#log_level('warn');

repeat_each(3);

plan tests => repeat_each() * (blocks() * 6);

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

=== TEST 1: ngx.worker.count
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local v
            local count = ngx.worker.count
            for i = 1, 400 do
                v = count()
            end
            ngx.say("workers: ", v)
        }
    }
--- request
GET /t
--- response_body
workers: 5
--- error_log eval
qr/\[TRACE   \d+ content_by_lua\(nginx\.conf:\d+\):4 loop\]/
--- no_error_log
[error]
 -- NYI:
 stitch
