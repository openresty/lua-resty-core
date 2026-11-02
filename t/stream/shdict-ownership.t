use lib '.';
use t::TestCore::Stream;

repeat_each(2);
plan tests => repeat_each() * blocks() * 3;

add_block_preprocessor(sub {
    my $block = shift;
    $block->set_value('stream_config', <<EOC);
    lua_shared_dict locks 1m;
    $t::TestCore::Stream::StreamConfig
EOC
});

no_long_string();
run_tests();

__DATA__

=== TEST 1: advertise the native capability and delete by default
--- stream_server_config
    content_by_lua_block {
        local shdict = require "resty.core.shdict"
        local dict = ngx.shared.locks
        ngx.say(shdict.has_atomic_ownership)
        dict:set("lock", "owner")
        ngx.say(dict:compare_expire("lock", "owner"))
        ngx.say(dict:get("lock"))
        ngx.say(dict:compare_expire("lock", "owner"))
    }
--- stream_response
true
true
nil
nillock ownership lost
--- no_error_log
[error]



=== TEST 2: renewal converts seconds to milliseconds and preserves flags
--- stream_server_config
    content_by_lua_block {
        local dict = ngx.shared.locks
        dict:set("lock", "owner", 1, 42)
        ngx.say(dict:compare_expire("lock", "owner", 5))
        ngx.say(dict:get("lock"))
        local ttl = dict:ttl("lock")
        ngx.say(ttl > 4 and ttl <= 5)
        ngx.say(dict:compare_expire("lock", "owner", 0.02))
        ngx.sleep(0.03)
        ngx.say(dict:compare_expire("lock", "owner", 1))
        ngx.say(dict:get("lock"))
    }
--- stream_response
true
owner42
true
true
nillock ownership lost
nil
--- no_error_log
[error]



=== TEST 3: zero expiry and string tokens including empty and binary values
--- stream_server_config
    content_by_lua_block {
        local dict = ngx.shared.locks
        dict:set("lock", "", 1)
        ngx.say(dict:compare_expire("lock", "", 0))
        ngx.say(dict:ttl("lock"))
        ngx.say(dict:compare_expire("lock", "", nil))
        local key = "lock\0key"
        local token = "owner\0token"
        dict:set(key, token)
        ngx.say(dict:compare_expire(key, "owner\0other"))
        ngx.say(dict:get(key) == token)
        ngx.say(dict:compare_expire(key, token))
        dict:set(123, "owner")
        ngx.say(dict:compare_expire(123, "owner"))
    }
--- stream_response
true
0
true
nillock ownership lost
true
true
true
--- no_error_log
[error]



=== TEST 4: an old owner cannot renew or delete a successor's lock
--- stream_server_config
    content_by_lua_block {
        local dict = ngx.shared.locks
        dict:set("lock", "old", 0.02)
        ngx.sleep(0.03)
        ngx.say(dict:add("lock", "new", 10))
        ngx.say(dict:compare_expire("lock", "old", 1))
        ngx.say(dict:compare_expire("lock", "old"))
        ngx.say(dict:get("lock"))
        ngx.say(dict:ttl("lock") > 9)
        ngx.say(dict:compare_expire("lock", "new"))
        ngx.say(dict:get("lock"))
    }
--- stream_response
truenilfalse
nillock ownership lost
nillock ownership lost
new
true
true
nil
--- no_error_log
[error]



=== TEST 5: mismatches and non-string entries preserve the current value
--- stream_server_config
    content_by_lua_block {
        local dict = ngx.shared.locks
        dict:set("lock", "owner")
        ngx.say(dict:compare_expire("lock", "other"))
        ngx.say(dict:compare_expire("lock", "own", 1))
        ngx.say(dict:get("lock"))
        ngx.say(dict:ttl("lock"))
        dict:set("number", 123)
        dict:set("boolean", true)
        dict:lpush("list", "owner")
        ngx.say(dict:compare_expire("number", "123"))
        ngx.say(dict:compare_expire("boolean", "true"))
        ngx.say(dict:compare_expire("list", "owner"))
        ngx.say(dict:get("number"))
        ngx.say(dict:get("boolean"))
        ngx.say(dict:lpop("list"))
    }
--- stream_response
nillock ownership lost
nillock ownership lost
owner
0
nillock ownership lost
nillock ownership lost
nillock ownership lost
123
true
owner
--- no_error_log
[error]



=== TEST 6: reject invalid keys and token types without deleting the entry
--- stream_server_config
    content_by_lua_block {
        local dict = ngx.shared.locks
        dict:set("lock", "owner")
        ngx.say(dict:compare_expire(nil, "owner"))
        ngx.say(dict:compare_expire("", "owner"))
        ngx.say(dict:compare_expire(string.rep("k", 65536), "owner"))
        ngx.say(dict:compare_expire("lock", nil))
        ngx.say(dict:compare_expire("lock", true))
        ngx.say(dict:compare_expire("lock", 123))
        ngx.say(dict:get("lock"))
    }
--- stream_response
nilnil key
nilempty key
nilkey too long
nilbad value type
nilbad value type
nilbad value type
owner
--- no_error_log
[error]



=== TEST 7: reject invalid and overflowing expiries before calling FFI
--- stream_server_config
    content_by_lua_block {
        local ffi = require "ffi"
        local dict = ngx.shared.locks
        dict:set("lock", "owner")
        local expiries = {
            -1, -0.001, false, "1", {}, 0 / 0, math.huge, -math.huge,
            2 ^ (ffi.sizeof("long") * 8 - 1) / 1000,
        }
        for i = 1, #expiries do
            ngx.say(dict:compare_expire("lock", "owner", expiries[i]))
        end

        ngx.say(dict:get("lock"))
        ngx.say(dict:ttl("lock"))
    }
--- stream_response
nilbad "exptime" argument
nilbad "exptime" argument
nilbad "exptime" argument
nilbad "exptime" argument
nilbad "exptime" argument
nilbad "exptime" argument
nilbad "exptime" argument
nilbad "exptime" argument
nilbad "exptime" argument
owner
0
--- no_error_log
[error]



=== TEST 8: ownership operations work in a compiled loop
--- stream_server_config
    content_by_lua_block {
        local traceinfo = require("jit.util").traceinfo
        jit.flush()
        local dict = ngx.shared.locks
        for i = 1, 100 do
            dict:set("lock", "owner")
            local ok, err = dict:compare_expire("lock", "owner", 1)
            if not ok then
                error(err)
            end

            ok, err = dict:compare_expire("lock", "owner")
            if not ok then
                error(err)
            end
        end

        ngx.say(dict:get("lock"))
        local compiled = false
        for i = 1, 100 do
            local info = traceinfo(i)
            if not info then
                break
            end

            if info.linktype == "loop" then
                compiled = true
                break
            end
        end

        ngx.say(compiled)
    }
--- stream_response
nil
true
--- no_error_log
[error]
