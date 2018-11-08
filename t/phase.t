# vim:set ft= ts=4 sw=4 et fdm=marker:
use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

repeat_each(2);

plan tests => repeat_each() * (blocks() * 5);

my $pwd = cwd();

our $HttpConfig = <<_EOC_;
    lua_package_path "$pwd/lib/?.lua;../lua-resty-lrucache/lib/?.lua;;";

    init_by_lua_block {
        local verbose = false
        if verbose then
            local dump = require "jit.dump"
            dump.on(nil, "$Test::Nginx::Util::ErrLogFile")
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

=== TEST 1: get_phase
--- http_config eval: $::HttpConfig
--- config
    location /lua {
        content_by_lua_block {
            local phase
            for i = 1, 100 do
                phase = ngx.get_phase()
            end
            ngx.say(phase)
        }
    }
--- request
GET /lua
--- response_body
content
--- no_error_log
[error]
 -- NYI:
--- error_log eval
qr/\[TRACE\s+\d+\s+content_by_lua\(nginx\.conf:\d+\):3 loop\]/
