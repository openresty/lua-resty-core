# vim:set ft= ts=4 sw=4 et fdm=marker:
use lib '.';
use t::TestCore;

#worker_connections(1014);
#master_process_enabled(1);
log_level('warn');

#repeat_each(120);
repeat_each(2);

plan tests => repeat_each() * (blocks() * 6);

#no_diff();
#no_long_string();
check_accum_error_log();
run_tests();

__DATA__

=== TEST 1: get ngx.ctx
--- config
    location = /t {
        content_by_lua_block {
            for i = 1, 100 do
                ngx.ctx.foo = i
            end
            ngx.say("ctx.foo = ", ngx.ctx.foo)
        }
    }
--- request
GET /t
--- response_body
ctx.foo = 100
--- no_error_log
[error]
 -- NYI:
 bad argument
--- error_log eval
qr/\[TRACE\s+\d+\s+content_by_lua\(nginx\.conf:\d+\):2 loop\]/



=== TEST 2: set ngx.ctx
--- config
    location = /t {
        content_by_lua_block {
            for i = 1, 100 do
                ngx.ctx = {foo = i}
            end
            ngx.say("ctx.foo = ", ngx.ctx.foo)
        }
    }
--- request
GET /t
--- response_body
ctx.foo = 100
--- no_error_log
[error]
 -- NYI:
 bad argument
--- error_log eval
qr/\[TRACE\s+\d+\s+content_by_lua\(nginx\.conf:\d+\):2 loop\]/
