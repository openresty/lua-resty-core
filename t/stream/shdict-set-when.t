# vim:set ft= ts=4 sw=4 et fdm=marker:
use lib '.';
use t::TestCore::Stream;

#worker_connections(1014);
#master_process_enabled(1);
#log_level('warn');

repeat_each(2);

plan tests => repeat_each() * (blocks() * 3 + 5);

add_block_preprocessor(sub {
    my $block = shift;

    my $stream_config = $block->stream_config || '';

    $stream_config .= <<_EOC_;
    lua_shared_dict dogs 1m;
    lua_shared_dict cats 16k;
    lua_shared_dict birds 100k;
    $t::TestCore::Stream::StreamConfig
_EOC_

    $block->set_value("stream_config", $stream_config);
});

#no_diff();
no_long_string();
check_accum_error_log();
run_tests();

__DATA__

=== TEST 1: set_when success
--- stream_server_config
    content_by_lua_block {
        local dogs = ngx.shared.dogs
        dogs:set("foo", 32)
        dogs:set_when("foo", 32, 33)
        local val = dogs:get("foo")
        ngx.say(val, " ", type(val))
    }
--- stream_response
33 number
--- no_error_log
[error]
 -- NYI:



=== TEST 2: set_when fail
--- stream_server_config
    content_by_lua_block {
        local dogs = ngx.shared.dogs
        dogs:set("foo", 32)
        local ok, err, forcible = dogs:set_when("foo", 32, 33)
        ngx.say(ok, " ", err, " ", forcible)
        local ok, err, forcible = dogs:set_when("foo", 32, 34)
        ngx.say(ok, " ", err, " ", forcible)
        local val = dogs:get("foo")
        ngx.say(val, " ", type(val))
    }
--- stream_response
true nil false
false already modified false
33 number
--- no_error_log
[error]
 -- NYI:



=== TEST 3: set_when success for expired value
--- stream_server_config
    content_by_lua_block {
        local dogs = ngx.shared.dogs
        dogs:set("foo", 32, 0.01)
        ngx.sleep(0.02)
        local ok, err, forcible = dogs:set_when("foo", 32, 33)
        ngx.say(ok, " ", err, " ", forcible)
        local val = dogs:get("foo")
        ngx.say(val, " ", type(val))
    }
--- stream_response
true nil false
33 number
--- no_error_log
[error]
 -- NYI:



=== TEST 4: set_when success for unmatched expired value
--- stream_server_config
    content_by_lua_block {
        local dogs = ngx.shared.dogs
        dogs:set("foo", 32, 0.01)
        ngx.sleep(0.02)
        local ok, err, forcible = dogs:set_when("foo", 31, 33)
        ngx.say(ok, " ", err, " ", forcible)
        local val = dogs:get("foo")
        ngx.say(val, " ", type(val))
    }
--- stream_response
true nil false
33 number
--- no_error_log
[error]
 -- NYI:



=== TEST 5: set_when success when old_value did not exist
--- stream_server_config
    content_by_lua_block {
        local dogs = ngx.shared.dogs
	dogs:flush_all()
        local ok, err, forcible = dogs:set_when("foo", 32, 33)
        ngx.say(ok, " ", err, " ", forcible)
        local val = dogs:get("foo")
        ngx.say(val, " ", type(val))
    }
--- stream_response
true nil false
33 number
--- no_error_log
[error]
 -- NYI:
