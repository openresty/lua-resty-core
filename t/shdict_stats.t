# vim:set ft= ts=4 sw=4 et fdm=marker:
use lib 'lib';
use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

#worker_connections(1014);
#master_process_enabled(1);
#log_level('debug');

repeat_each(1);

plan tests => repeat_each() * (blocks() * 5);

my $pwd = cwd();

our $HttpConfig = <<_EOC_;
    lua_shared_dict dogs 16k;
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

#no_diff();
#no_long_string();
check_accum_error_log();
run_tests();

__DATA__

=== TEST 1: stats, empty
--- skip_nginx: 5: < 1.11.7
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local dogs = ngx.shared.dogs
            dogs:flush_all()
            dogs:flush_expired()
            local free_page_bytes = dogs:stats()
            ngx.say("free_page_bytes type: ", type(free_page_bytes))
            ngx.say("free_page_bytes: ", free_page_bytes)
        }
    }
--- request
GET /t
--- response_body
free_page_bytes type: number
free_page_bytes: 4096
--- no_error_log
[error]
[alert]
[crit]



=== TEST 2: stats, about half full, one page left
--- skip_nginx: 5: < 1.11.7
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local dogs = ngx.shared.dogs
            dogs:flush_all()
            dogs:flush_expired()
            for i = 1, 31 do
                local key = string.format("key%05d", i)
                local val = string.format("val%05d", i)
                local success, err, forcible = dogs:set(key, val)
                if err ~= nil then
                    ngx.say(string.format("got error, i=%d, err=%s", i, err))
                end
                if forcible then
                    ngx.say(string.format("got forcible, i=%d", i))
                end
                if not success then
                    ngx.say(string.format("got not success, i=%d", i))
                end
            end
            local free_page_bytes = dogs:stats()
            ngx.say("free_page_bytes type: ", type(free_page_bytes))
            ngx.say("free_page_bytes: ", free_page_bytes)
        }
    }
--- request
GET /t
--- response_body
free_page_bytes type: number
free_page_bytes: 4096
--- no_error_log
[error]
[alert]
[crit]



=== TEST 3: stats, about half full, no page left
--- skip_nginx: 5: < 1.11.7
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local dogs = ngx.shared.dogs
            dogs:flush_all()
            dogs:flush_expired()
            for i = 1, 32 do
                local key = string.format("key%05d", i)
                local val = string.format("val%05d", i)
                local success, err, forcible = dogs:set(key, val)
                if err ~= nil then
                    ngx.say(string.format("got error, i=%d, err=%s", i, err))
                end
                if forcible then
                    ngx.say(string.format("got forcible, i=%d", i))
                end
                if not success then
                    ngx.say(string.format("got not success, i=%d", i))
                end
            end
            local free_page_bytes = dogs:stats()
            ngx.say("free_page_bytes type: ", type(free_page_bytes))
            ngx.say("free_page_bytes: ", free_page_bytes)
        }
    }
--- request
GET /t
--- response_body
free_page_bytes type: number
free_page_bytes: 0
--- no_error_log
[error]
[alert]
[crit]



=== TEST 4: stats, full
--- skip_nginx: 5: < 1.11.7
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local dogs = ngx.shared.dogs
            dogs:flush_all()
            dogs:flush_expired()
            for i = 1, 63 do
                local key = string.format("key%05d", i)
                local val = string.format("val%05d", i)
                local success, err, forcible = dogs:set(key, val)
                if err ~= nil then
                    ngx.say(string.format("got error, i=%d, err=%s", i, err))
                end
                if forcible then
                    ngx.say(string.format("got forcible, i=%d", i))
                end
                if not success then
                    ngx.say(string.format("got not success, i=%d", i))
                end
            end
            local free_page_bytes = dogs:stats()
            ngx.say("free_page_bytes type: ", type(free_page_bytes))
            ngx.say("free_page_bytes: ", free_page_bytes)
        }
    }
--- request
GET /t
--- response_body
free_page_bytes type: number
free_page_bytes: 0
--- no_error_log
[error]
[alert]
[crit]



=== TEST 5: stats, got forcible
--- skip_nginx: 5: < 1.11.7
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local dogs = ngx.shared.dogs
            dogs:flush_all()
            dogs:flush_expired()
            for i = 1, 64 do
                local key = string.format("key%05d", i)
                local val = string.format("val%05d", i)
                local success, err, forcible = dogs:set(key, val)
                if err ~= nil then
                    ngx.say(string.format("got error, i=%d, err=%s", i, err))
                end
                if forcible then
                    ngx.say(string.format("got forcible, i=%d", i))
                end
                if not success then
                    ngx.say(string.format("got not success, i=%d", i))
                end
            end
            local free_page_bytes = dogs:stats()
            ngx.say("free_page_bytes type: ", type(free_page_bytes))
            ngx.say("free_page_bytes: ", free_page_bytes)
        }
    }
--- request
GET /t
--- response_body
got forcible, i=64
free_page_bytes type: number
free_page_bytes: 0
--- no_error_log
[error]
[alert]
[crit]
