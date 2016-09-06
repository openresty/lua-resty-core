# vim:set ft= ts=4 sw=4 et fdm=marker:

#use Test::Nginx::Socket 'no_plan';
use Test::Nginx::Socket::Lua 'no_plan';
use Cwd qw(cwd);

#worker_connections(1014);
#master_on();
#workers(2);
#log_level('warn');

#repeat_each(2);

#plan tests => repeat_each() * (blocks() * 2);

$ENV{TEST_NGINX_CWD} = cwd();

#no_diff();
#no_long_string();
run_tests();

__DATA__

=== TEST 1: set_more_tries bugfix
--- http_config
    lua_package_path "$TEST_NGINX_CWD/lib/?.lua;;";
    upstream backend {
        server 0.0.0.1;
        balancer_by_lua_block {
            local balancer = require "ngx.balancer"
            local _, err = balancer.set_more_tries(30)
            if err then
                print(err)
            end
        }
    }
--- config
    location = /t {
        proxy_pass http://backend;
    }
--- request
    GET /t
--- error_code: 502
--- no_error_log
reduced tries due to limit
