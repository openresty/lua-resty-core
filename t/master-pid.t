# vim:set ft= ts=4 sw=4 et fdm=marker:
use lib 'lib';
use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

#worker_connections(1014);
#master_process_enabled(1);
#log_level('warn');

master_on();
repeat_each(2);

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

=== TEST 1: sanity
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local process = require "ngx.process"

            local v
            local get_pid = process.get_master_pid
            for i = 1, 400 do
                v = get_pid()
            end

            local f = assert(io.open(ngx.config.prefix() .. "/logs/nginx.pid", "r"))
            local str = assert(f:read("*l"))
            local expected = str
            if tostring(v) == expected then
                ngx.say("ok")
            else
                ngx.say("expected: ", expected)
            end
            f:close()
            ngx.say("got: ", v, " (", type(v), ")")
        }
    }
--- request
GET /t
--- response_body_like chop
\Aok
got: \d+ \(number\)
\z
--- error_log eval
qr/\[TRACE   \d+ content_by_lua\(nginx\.conf:\d+\):\d loop\]/
--- no_error_log
[error]
 -- NYI:
 stitch
--- skip_nginx: 6: < 1.13.8
