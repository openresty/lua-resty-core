# vim:set ft= ts=4 sw=4 et fdm=marker:
use lib 'lib';
use Test::Nginx::Socket;
use Cwd qw(cwd);

#worker_connections(1014);
#master_process_enabled(1);
#log_level('warn');

repeat_each(2);

plan tests => repeat_each() * (blocks() * 5);

my $pwd = cwd();

our $HttpConfig = <<_EOC_;
    lua_package_path "$pwd/lib/?.lua;;";
    init_by_lua '
        local verbose = false
        if verbose then
            local dump = require "jit.dump"
            dump.on(nil, "$Test::Nginx::Util::ErrLogFile")
        else
            local v = require "jit.v"
            v.on("$Test::Nginx::Util::ErrLogFile")
        end

        require "resty.core.base64"
        -- jit.off()
    ';
_EOC_

#no_diff();
#no_long_string();
run_tests();

__DATA__

=== TEST 1: set base64 (string)
--- http_config eval: $::HttpConfig
--- config
    location = /base64 {
        content_by_lua '
            local s
            for i = 1, 100 do
                s = ngx.encode_base64("hello")
            end
            ngx.say(s)
        ';
    }
--- request
GET /base64
--- response_body
aGVsbG8=
--- error_log eval
qr/\[TRACE   \d+ "content_by_lua":3 loop\]/
--- no_error_log
[error]
 -- NYI:



=== TEST 2: set base64 (nil)
--- http_config eval: $::HttpConfig
--- config
    location = /base64 {
        content_by_lua '
            local s
            for i = 1, 100 do
                s = ngx.encode_base64(nil)
            end
            ngx.say(s)
        ';
    }
--- request
GET /base64
--- response_body eval: "\n"
--- error_log eval
qr/\[TRACE   \d+ "content_by_lua":3 loop\]/
--- no_error_log
[error]
 -- NYI:



=== TEST 3: set base64 (number)
--- http_config eval: $::HttpConfig
--- config
    location = /base64 {
        content_by_lua '
            local s
            for i = 1, 100 do
                s = ngx.encode_base64(3.14)
            end
            ngx.say(s)
        ';
    }
--- request
GET /base64
--- response_body
My4xNA==
--- error_log eval
qr/\[TRACE   \d+ "content_by_lua":3 loop\]/
--- no_error_log
[error]
 -- NYI:



=== TEST 4: set base64 (boolean)
--- http_config eval: $::HttpConfig
--- config
    location = /base64 {
        content_by_lua '
            local s
            for i = 1, 100 do
                s = ngx.encode_base64(true)
            end
            ngx.say(s)
        ';
    }
--- request
GET /base64
--- response_body
dHJ1ZQ==
--- error_log eval
qr/\[TRACE   \d+ "content_by_lua":3 loop\]/
--- no_error_log
[error]
 -- NYI:

