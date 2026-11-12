# vim:set ft= ts=4 sw=4 et fdm=marker:
use lib '.';
use t::TestCore;

repeat_each(2);

plan tests => repeat_each() * (blocks() * 5);

check_accum_error_log();
run_tests();

__DATA__

=== TEST 1: get_phase
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



=== TEST 2: get_phase in server_name_resolver_by_lua_block
--- skip_eval: 5: my $nginx = `sh -c 'command -v \${TEST_NGINX_BINARY:-nginx}'`; chomp $nginx; system("grep -q 'server_name_resolver_by_lua_block' '$nginx'") != 0 || system("grep -q 'requires nginx with the server_name_resolver hook' '$nginx'") == 0
--- http_config eval
"$t::TestCore::HttpConfig" . q{
    server_name_resolver_by_lua_block {
        ngx.log(ngx.WARN, "phase: ", ngx.get_phase())
    }

    server {
        listen $TEST_NGINX_SERVER_PORT;
        server_name other.test;

        location /lua {
            return 200 "ok\n";
        }
    }
}
--- config
--- more_headers
Host: alias.test
--- request
GET /lua
--- response_body
ok
--- no_error_log
[error]
 -- NYI:
--- error_log
phase: server_name_resolver
