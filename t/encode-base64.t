# vim:set ft= ts=4 sw=4 et fdm=marker:
use lib 'lib';
use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

#worker_connections(1014);
#master_process_enabled(1);
#log_level('warn');

repeat_each(2);

plan tests => repeat_each() * (blocks() * 5 - 1);

my $pwd = cwd();

our $HttpConfig = <<_EOC_;
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

=== TEST 1: set base64 (string)
--- http_config eval: $::HttpConfig
--- config
    location = /base64 {
        content_by_lua_block {
            local s
            for i = 1, 100 do
                s = ngx.encode_base64("hello")
            end
            ngx.say(s)
        }
    }
--- request
GET /base64
--- response_body
aGVsbG8=
--- error_log eval
qr/\[TRACE   \d+ content_by_lua\(nginx\.conf:\d+\):3 loop\]/
--- no_error_log
[error]
 -- NYI:



=== TEST 2: set base64 (nil)
--- http_config eval: $::HttpConfig
--- config
    location = /base64 {
        content_by_lua_block {
            local s
            for i = 1, 100 do
                s = ngx.encode_base64(nil)
            end
            ngx.say(s)
        }
    }
--- request
GET /base64
--- response_body eval: "\n"
--- error_log eval
qr/\[TRACE   \d+ content_by_lua\(nginx\.conf:\d+\):3 loop\]/
--- no_error_log
[error]
 -- NYI:



=== TEST 3: set base64 (number)
--- http_config eval: $::HttpConfig
--- config
    location = /base64 {
        content_by_lua_block {
            local s
            for i = 1, 100 do
                s = ngx.encode_base64(3.14)
            end
            ngx.say(s)
        }
    }
--- request
GET /base64
--- response_body
My4xNA==
--- error_log eval
qr/\[TRACE   \d+ content_by_lua\(nginx\.conf:\d+\):3 loop\]/
--- no_error_log
[error]
 -- NYI:



=== TEST 4: set base64 (boolean)
--- http_config eval: $::HttpConfig
--- config
    location = /base64 {
        content_by_lua_block {
            local s
            for i = 1, 100 do
                s = ngx.encode_base64(true)
            end
            ngx.say(s)
        }
    }
--- request
GET /base64
--- response_body
dHJ1ZQ==
--- error_log eval
qr/\[TRACE   \d+ content_by_lua\(nginx\.conf:\d+\):3 loop\]/
--- no_error_log
[error]
 -- NYI:



=== TEST 5: set base64 (buf is a little larger than 4096)
--- http_config eval: $::HttpConfig
--- config
    location = /base64 {
        content_by_lua_block {
            local s
            for i = 1, 100 do
                s = ngx.encode_base64(string.rep("a", 3073))
            end
            ngx.say(string.len(s))
        }
    }
--- request
GET /base64
--- response_body
4100
--- error_log eval
qr/\[TRACE   \d+ content_by_lua\(nginx\.conf:\d+\):3 loop\]/
--- no_error_log
[error]
 -- NYI:



=== TEST 6: set base64 (buf is just 4096)
--- http_config eval: $::HttpConfig
--- config
    location = /base64 {
        content_by_lua_block {
            local s
            for i = 1, 100 do
                s = ngx.encode_base64(string.rep("a", 3071))
            end
            ngx.say(string.len(s))
        }
    }
--- request
GET /base64
--- response_body
4096
--- error_log eval
qr/\[TRACE   \d+ content_by_lua\(nginx\.conf:\d+\):3 loop\]/
--- no_error_log
[error]
 -- NYI:



=== TEST 7: set base64 (number) without padding (explicitly specified)
--- http_config eval: $::HttpConfig
--- config
    location = /base64 {
        content_by_lua_block {
            local s
            for i = 1, 200 do
                s = ngx.encode_base64(3.14, true)
            end
            ngx.say(s)
        }
    }
--- request
GET /base64
--- response_body
My4xNA
--- error_log eval
qr/\[TRACE   \d+ content_by_lua\(nginx\.conf:\d+\):3 loop\]/
--- no_error_log
[error]
 -- NYI:



=== TEST 8: set base64 (number) with padding (explicitly specified)
--- http_config eval: $::HttpConfig
--- config
    location = /base64 {
        content_by_lua_block {
            local s
            for i = 1, 200 do
                s = ngx.encode_base64(3.14, false)
            end
            ngx.say(s)
        }
    }
--- request
GET /base64
--- response_body
My4xNA==
--- error_log eval
qr/\[TRACE   \d+ content_by_lua\(nginx\.conf:\d+\):3 loop\]/
--- no_error_log
[error]
 -- NYI:



=== TEST 9: encode_base64url
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local enc = require("ngx.base64")

            -- RFC 4648 test vectors
            ngx.say("encode_base64url(\"\") = \"", enc.encode_base64url(""), "\"")
            ngx.say("encode_base64url(\"f\") = \"", enc.encode_base64url("f"), "\"")
            ngx.say("encode_base64url(\"fo\") = \"", enc.encode_base64url("fo"), "\"")
            ngx.say("encode_base64url(\"foo\") = \"", enc.encode_base64url("foo"), "\"")
            ngx.say("encode_base64url(\"foob\") = \"", enc.encode_base64url("foob"), "\"")
            ngx.say("encode_base64url(\"fooba\") = \"", enc.encode_base64url("fooba"), "\"")
            ngx.say("encode_base64url(\"foobar\") = \"", enc.encode_base64url("foobar"), "\"")
            ngx.say("encode_base64url(\"\\xff\") = \"", enc.encode_base64url("\xff"), "\"")

            ngx.say("encode_base64url(\"a\\0b\") = \"", enc.encode_base64url("a\0b"), "\"")
        }
    }
--- request
GET /t
--- response_body
encode_base64url("") = ""
encode_base64url("f") = "Zg"
encode_base64url("fo") = "Zm8"
encode_base64url("foo") = "Zm9v"
encode_base64url("foob") = "Zm9vYg"
encode_base64url("fooba") = "Zm9vYmE"
encode_base64url("foobar") = "Zm9vYmFy"
encode_base64url("\xff") = "_w"
encode_base64url("a\0b") = "YQBi"
--- no_error_log
[error]
 -- NYI:
