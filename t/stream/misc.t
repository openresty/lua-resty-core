# vim:set ft= ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua::Stream;use Cwd qw(cwd);

#worker_connections(1014);
#master_on();
#workers(2);
#log_level('warn');

repeat_each(2);

plan tests => repeat_each() * (blocks() * 5);

$ENV{TEST_NGINX_CWD} = cwd();

#worker_connections(1024);
#no_diff();
no_long_string();
run_tests();

__DATA__

=== TEST 1: base.check_subsystem
--- stream_config
    lua_package_path "$TEST_NGINX_CWD/lib/?.lua;;";
--- stream_server_config
    content_by_lua_block {
        local base = require "resty.core.base"
        base.allows_subsystem('http', 'stream')
        base.allows_subsystem('stream')

        ngx.say("ok")
    }
--- stream_response
ok
--- no_error_log
[error]
 -- NYI:
 bad argument



=== TEST 2: base.check_subsystem with non-stream subsystem
--- stream_config
    lua_package_path "$TEST_NGINX_CWD/lib/?.lua;;";
--- stream_server_config
    content_by_lua_block {
        local base = require "resty.core.base"
        base.allows_subsystem('http')

        ngx.say("ok")
    }
--- stream_response
--- no_error_log
 -- NYI:
 bad argument
--- error_log
unsupported subsystem: stream
