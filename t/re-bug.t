# vim:set ft= ts=4 sw=4 et fdm=marker:
use lib 'lib';
use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

repeat_each(2);

plan tests => repeat_each() * (blocks() * 4);

my $pwd = cwd();

our $HttpConfig = <<_EOC_;
    lua_package_path "$pwd/lib/?.lua;../lua-resty-lrucache/lib/?.lua;;";
    init_by_lua_block {
        require "resty.core"
        ngx.re.match('c', 'test', 'jo')
    }
_EOC_

no_long_string();
check_accum_error_log();
run_tests();

__DATA__

=== TEST 1: PCRE MAP_JIT bug on macOS
--- skip_eval
4: $^O ne 'darwin'
--- http_config eval: $::HttpConfig
--- config
    location /re {
        content_by_lua_block {
            ngx.say(ngx.re.sub('c', 'a', 'b', ''))
            ngx.say(ngx.re.sub('c', 'a', 'b', 'jo'))
            ngx.say("it works!")
        }
    }
--- request
    GET /re
--- response_body
c0
c0
it works!
--- grep_error_log eval
qr/.+parse_regex_opts\(\): running regex in init phase under macOS,.+/
--- grep_error_log_out eval
qr/(:?.+parse_regex_opts\(\): running regex in init phase under macOS,.+){2}/s
--- no_error_log
[error]



=== TEST 2: PCRE MAP_JIT bug fix does not affect other O/Ses
--- skip_eval
4: $^O ne 'linux'
--- http_config eval: $::HttpConfig
--- config
    location /re {
        content_by_lua_block {
            ngx.say(ngx.re.sub('c', 'a', 'b', ''))
            ngx.say(ngx.re.sub('c', 'a', 'b', 'jo'))
            ngx.say("it works!")
        }
    }
--- request
    GET /re
--- response_body
c0
c0
it works!

--- no_error_log
[error]
running regex in init phase under macOS
