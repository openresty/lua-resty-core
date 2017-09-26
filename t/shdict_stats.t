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
    lua_shared_dict dogs 1m;
    lua_shared_dict empty_cats 12k;
    lua_shared_dict half_full_cats 12k;
    lua_shared_dict full_cats 12k;
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
            local cats = ngx.shared.empty_cats
            local used, total = cats:stats()
            ngx.say("used type: ", type(used))
            ngx.say("total type: ", type(total))
            ngx.say("used: ", used)
            ngx.say("total: ", total)
        }
    }
--- request
GET /t
--- response_body eval
# I confirmed that ngx_http_lua_shdict_init_zone calls ngx_slab_alloc 2 times, 1 time each for below lines.
#
# * https://github.com/openresty/lua-nginx-module/blob/bf14723e4e7749c989134c029742185db1c78255/src/ngx_http_lua_shdict.c#L108
#   - sizeof(ngx_http_lua_shdict_shctx_t) = 80 and the slot of size 128 is used.
# * https://github.com/openresty/lua-nginx-module/blob/bf14723e4e7749c989134c029742185db1c78255/src/ngx_http_lua_shdict.c#L120
#   - If the shared dict name is empty_cats, sizeof(" in lua_shared_dict zone \"\"") + shm_zone->shm.name.len = 38 and the slot of size 64 is used.
"used type: number
total type: number
used: " . (1 + 1) . "
total: " . (128 + 64) . "
"
--- no_error_log
[error]
[alert]
[crit]



=== TEST 2: stats, one_key
--- skip_nginx: 5: < 1.11.7
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local cats = ngx.shared.empty_cats
            local key = "key00001"
            local val = "val00001"
            cats:set(key, val)
            local used, total = cats:stats()
            ngx.say("used: ", used)
            ngx.say("total: ", total)
        }
    }
--- request
GET /t
--- response_body eval
# https://github.com/openresty/lua-nginx-module/blob/bf14723e4e7749c989134c029742185db1c78255/src/ngx_http_lua_shdict.c#L2408-L2411
# n = offsetof(ngx_rbtree_node_t, color)
#     + offsetof(ngx_http_lua_shdict_node_t, data)
#     + key_len
#     + str_value_len;
#   = 32 + 36 + 8 + 8
#   = 84
# So a slot of size 128 is used.
"used: 3
total: " . (128 + 64 + 128) . "
"
--- no_error_log
[error]
[alert]
[crit]



=== TEST 3: stats, add and delete key
--- skip_nginx: 5: < 1.11.7
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local cats = ngx.shared.empty_cats
            local key = "key00001"
            local val = "val00001"
            cats:set(key, val)
            cats:delete(key)
            local used, total = cats:stats()
            ngx.say("used: ", used)
            ngx.say("total: ", total)
        }
    }
--- request
GET /t
--- response_body
used: 2
total: 192
--- no_error_log
[error]
[alert]
[crit]



=== TEST 4: stats, add, flush_all, and flush_expired
--- skip_nginx: 5: < 1.11.7
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local cats = ngx.shared.empty_cats
            local key = "key00001"
            local val = "val00001"
            cats:set(key, val)
            cats:flush_all()
            cats:flush_expired()
            local used, total = cats:stats()
            ngx.say("used: ", used)
            ngx.say("total: ", total)
        }
    }
--- request
GET /t
--- response_body
used: 2
total: 192
--- no_error_log
[error]
[alert]
[crit]



=== TEST 5: stats, add two keys
--- skip_nginx: 5: < 1.11.7
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local cats = ngx.shared.empty_cats
            cats:flush_all()
            cats:flush_expired()
            for i = 1, 2 do
                local key = string.format("key%05d", i)
                local val = string.format("val%05d", i)
                cats:set(key, val)
            end
            local used, total = cats:stats()
            ngx.say("used: ", used)
            ngx.say("total: ", total)
        }
    }
--- request
GET /t
--- response_body
used: 4
total: 448
--- no_error_log
[error]
[alert]
[crit]



=== TEST 6: stats, add three keys
--- skip_nginx: 5: < 1.11.7
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local cats = ngx.shared.empty_cats
            cats:flush_all()
            cats:flush_expired()
            for i = 1, 3 do
                local key = string.format("key%05d", i)
                local val = string.format("val%05d", i)
                cats:set(key, val)
            end
            local used, total = cats:stats()
            ngx.say("used: ", used)
            ngx.say("total: ", total)
        }
    }
--- request
GET /t
--- response_body
used: 5
total: 576
--- no_error_log
[error]
[alert]
[crit]



=== TEST 7: stats, add ten keys
--- skip_nginx: 5: < 1.11.7
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local cats = ngx.shared.empty_cats
            cats:flush_all()
            cats:flush_expired()
            for i = 1, 10 do
                local key = string.format("key%05d", i)
                local val = string.format("val%05d", i)
                cats:set(key, val)
            end
            local used, total = cats:stats()
            ngx.say("used: ", used)
            ngx.say("total: ", total)
        }
    }
--- request
GET /t
--- response_body
used: 12
total: 1472
--- no_error_log
[error]
[alert]
[crit]



=== TEST 8: stats, add thirty keys
--- skip_nginx: 5: < 1.11.7
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local cats = ngx.shared.empty_cats
            cats:flush_all()
            cats:flush_expired()
            for i = 1, 30 do
                local key = string.format("key%05d", i)
                local val = string.format("val%05d", i)
                cats:set(key, val)
            end
            local used, total = cats:stats()
            ngx.say("used: ", used)
            ngx.say("total: ", total)
        }
    }
--- request
GET /t
--- response_body
used: 32
total: 4032
--- no_error_log
[error]
[alert]
[crit]



=== TEST 9: stats, add thirty-one keys
--- skip_nginx: 5: < 1.11.7
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local cats = ngx.shared.empty_cats
            cats:flush_all()
            cats:flush_expired()
            for i = 1, 31 do
                local key = string.format("key%05d", i)
                local val = string.format("val%05d", i)
                cats:set(key, val)
            end
            local used, total = cats:stats()
            ngx.say("used: ", used)
            ngx.say("total: ", total)
        }
    }
--- request
GET /t
--- response_body
used: 33
total: 4160
--- no_error_log
[error]
[alert]
[crit]



=== TEST 10: stats, add thirty-two keys
--- skip_nginx: 5: < 1.11.7
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local cats = ngx.shared.empty_cats
            cats:flush_all()
            cats:flush_expired()
            for i = 1, 32 do
                local key = string.format("key%05d", i)
                local val = string.format("val%05d", i)
                success, err, forcible = cats:set(key, val)
                if err ~= nil then
                   ngx.say(string.format("got error for i=%d, err=%s", i, err))
                end
                if forcible then
                   ngx.say(string.format("got forcible for i=%d", i))
                end
                if not success then
                   ngx.say(string.format("got not success for i=%d", i))
                end
            end
            local used, total = cats:stats()
            ngx.say("used: ", used)
            ngx.say("total: ", total)
        }
    }
--- request
GET /t
--- response_body
got forcible for i=32
used: 33
total: 4160
--- no_error_log
[error]
[alert]
[crit]



=== TEST 11: stats, add thirty-two keys, one key with len=53
--- skip_nginx: 5: < 1.11.7
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local cats = ngx.shared.empty_cats
            cats:flush_all()
            cats:flush_expired()
            for i = 1, 31 do
                local key = string.format("key%05d", i)
                local val = string.format("val%05d", i)
                local success, err, forcible = cats:set(key, val)
                if err ~= nil then
                   ngx.say(string.format("got error for i=%d, err=%s", i, err))
                end
                if forcible then
                   ngx.say(string.format("got forcible for i=%d", i))
                end
                if not success then
                   ngx.say(string.format("got not success for i=%d", i))
                end
            end
            local i = 32
            local key = string.format("key%05d", i)
            local val = string.format("val%05d", i) .. string.rep("a", 45)
            local success, err, forcible = cats:set(key, val)
            if err ~= nil then
               ngx.say(string.format("got error for i=%d, err=%s", i, err))
            end
            if forcible then
               ngx.say(string.format("got forcible for i=%d", i))
            end
            if not success then
               ngx.say(string.format("got not success for i=%d", i))
            end
            local used, total = cats:stats()
            ngx.say("used: ", used)
            ngx.say("total: ", total)
        }
    }
--- request
GET /t
--- response_body
got error for i=32, err=no memory
got forcible for i=32
got not success for i=32
used: 3
total: 320
--- no_error_log
[error]
[alert]
[crit]



=== TEST 12: stats, add thirty-two keys, one key with len=54
--- skip_nginx: 5: < 1.11.7
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local cats = ngx.shared.empty_cats
            cats:flush_all()
            cats:flush_expired()
            for i = 1, 31 do
                local key = string.format("key%05d", i)
                local val = string.format("val%05d", i)
                local success, err, forcible = cats:set(key, val)
                if err ~= nil then
                   ngx.say(string.format("got error for i=%d, err=%s", i, err))
                end
                if forcible then
                   ngx.say(string.format("got forcible for i=%d", i))
                end
                if not success then
                   ngx.say(string.format("got not success for i=%d", i))
                end
            end
            local i = 32
            local key = string.format("key%05d", i)
            local val = string.format("val%05d", i) .. string.rep("a", 46)
            local success, err, forcible = cats:set(key, val)
            if err ~= nil then
               ngx.say(string.format("got error for i=%d, err=%s", i, err))
            end
            if forcible then
               ngx.say(string.format("got forcible for i=%d", i))
            end
            if not success then
               ngx.say(string.format("got not success for i=%d", i))
            end
            local used, total = cats:stats()
            ngx.say("used: ", used)
            ngx.say("total: ", total)
        }
    }
--- request
GET /t
--- response_body
got error for i=32, err=no memory
got forcible for i=32
got not success for i=32
used: 3
total: 320
--- no_error_log
[error]
[alert]
[crit]



=== TEST 13: stats, add thirty-two keys, one key with len=256
--- skip_nginx: 5: < 1.11.7
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local cats = ngx.shared.empty_cats
            cats:flush_all()
            cats:flush_expired()
            for i = 1, 31 do
                local key = string.format("key%05d", i)
                local val = string.format("val%05d", i)
                local success, err, forcible = cats:set(key, val)
                if err ~= nil then
                   ngx.say(string.format("got error for i=%d, err=%s", i, err))
                end
                if forcible then
                   ngx.say(string.format("got forcible for i=%d", i))
                end
                if not success then
                   ngx.say(string.format("got not success for i=%d", i))
                end
            end
            local i = 32
            local key = string.format("key%05d", i)
            local val = string.format("val%05d", i) .. string.rep("a", 248)
            local success, err, forcible = cats:set(key, val)
            if err ~= nil then
               ngx.say(string.format("got error for i=%d, err=%s", i, err))
            end
            if forcible then
               ngx.say(string.format("got forcible for i=%d", i))
            end
            if not success then
               ngx.say(string.format("got not success for i=%d", i))
            end
            local used, total = cats:stats()
            ngx.say("used: ", used)
            ngx.say("total: ", total)
        }
    }
--- request
GET /t
--- response_body
got error for i=32, err=no memory
got forcible for i=32
got not success for i=32
used: 3
total: 320
--- no_error_log
[error]
[alert]
[crit]
