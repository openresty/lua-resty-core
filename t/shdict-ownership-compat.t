use Test::Nginx::Socket::Lua::Stream;

repeat_each(2);
plan tests => repeat_each() * blocks() * 3;

add_block_preprocessor(sub {
    my $block = shift;
    my $subsystem = $block->subsystem;
    chomp $subsystem;
    my $expected = $ENV{'TEST_NGINX_ATOMIC_OWNERSHIP_' . uc $subsystem};
    my $check = '';
    if (defined $expected) {
        my $boolean = $expected ? 'true' : 'false';
        $check = <<EOC;
        if native ~= $boolean then
            error("unexpected native ownership capability: " .. tostring(native))
        end
EOC
    }

    my $content = <<'EOC';
        local ffi = require "ffi"
        local shdict = require "resty.core.shdict"
        local native = pcall(function ()
            return ffi.C["ngx_" .. ngx.config.subsystem
                         .. "_lua_ffi_shdict_compare_expire"]
        end)
EOC
    $content .= $check . <<'EOC';
        local dict = ngx.shared.locks
        ngx.say(type(shdict.has_atomic_ownership))
        ngx.say(shdict.has_atomic_ownership == native)
        ngx.say(type(dict.compare_expire))
        dict:set("lock", "owner", 0, 42)
        local ok, err = dict:compare_expire("lock", "owner", 0)
        if native then
            ngx.say(ok == true and err == nil)

        else
            ngx.say(ok == nil and err ==
                    "atomic ownership operations require an updated nginx")
        end

        ngx.say(dict:get("lock"))
        local count = dict:incr("counter", 1, 0)
        ngx.say(count)
        dict:delete("counter")
EOC
    my $config = <<'EOC';
    lua_shared_dict locks 1m;
    lua_package_path './lib/?.lua;../lua-resty-lrucache/lib/?.lua;;';
EOC

    if ($subsystem eq 'http') {
        $block->set_value('http_config', $config);
        $block->set_value('config', <<EOC);
    location = /t {
        content_by_lua_block {
$content
        }
    }
EOC

    } else {
        $block->set_value('stream_config', $config);
        $block->set_value('stream_server_config', <<EOC);
    content_by_lua_block {
$content
    }
EOC
    }
});

no_long_string();
run_tests();

__DATA__

=== TEST 1: HTTP detects native support without breaking existing APIs
--- subsystem: http
--- request
GET /t
--- response_body
boolean
true
function
true
owner42
1
--- no_error_log
[error]



=== TEST 2: stream detects native support without breaking existing APIs
--- subsystem: stream
--- stream_response
boolean
true
function
true
owner42
1
--- no_error_log
[error]
