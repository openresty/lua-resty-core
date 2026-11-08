# vim:set ft= ts=4 sw=4 et fdm=marker:

use lib '.';
use t::TestCore::Stream;

#worker_connections(1014);
#master_process_enabled(1);
#log_level('warn');

repeat_each(2);

plan tests => repeat_each() * blocks() * 3;

no_diff();
no_long_string();
check_accum_error_log();
run_tests();

__DATA__

=== TEST 1: keepalive interval and keepalive cnt
--- stream_server_config
    content_by_lua_block {
        require "resty.core.socket"

        local port = ngx.var.server_port
        local sock = ngx.socket.tcp()
        local ok, err = sock:connect("127.0.0.1", port)
        if not ok then
            ngx.say("failed to connect: ", err)
            return
        end

        local v1, err = sock:getoption("keepalive")
        if not v1 then
            ngx.say("get default keepalive failed: ", err)
            return
        end

        ok, err = sock:setoption("keepalive", 10)
        if not ok then
            ngx.say("enabling keepalive failed: ", err)
            return
        end
        local v2, err = sock:getoption("keepalive")
        if not v2 then
            ngx.say("get enabled keepalive failed: ", err)
            return
        end
        ngx.say("keepalive changes from ", v1, " to ", v2)

        ok, err = sock:setoption("keepintvl", 3)
        if not ok then
            ngx.say("enable keepintvl failed: ", err)
            return
        end
        local intvl, err = sock:getoption("keepintvl")
        if not intvl then
            ngx.say("get keepintvl failed: ", err)
            return
        end
        ngx.say("keepintvl is ", intvl)

        ok, err = sock:setoption("keepcnt", 5)
        if not ok then
            ngx.say("enable keepcnt failed: ", err)
            return
        end
        local keepcnt, err = sock:getoption("keepcnt")
        if not intvl then
            ngx.say("get keepcnt failed: ", err)
            return
        end
        ngx.say("keepcnt is ", keepcnt)
        sock:close()
    }
--- stream_response
keepalive changes from 0 to 1
keepintvl is 3
keepcnt is 5
--- no_error_log
[error]
