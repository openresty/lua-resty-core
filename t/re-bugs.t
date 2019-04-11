# vim:set ft= ts=4 sw=4 et fdm=marker:
use lib '.';
use t::TestCore;

repeat_each(2);

plan tests => repeat_each() * (blocks() * 4);

add_block_preprocessor(sub {
    my $block = shift;

    my $http_config = $block->http_config || '';
    my $init_by_lua_block = $block->init_by_lua_block || '';

    $http_config .= <<_EOC_;
    lua_package_path '$t::TestCore::lua_package_path';
    init_by_lua_block {
        $t::TestCore::init_by_lua_block
        $init_by_lua_block
    }
_EOC_

    $block->set_value("http_config", $http_config);
});

no_long_string();
check_accum_error_log();
run_tests();

__DATA__

=== TEST 1: PCRE MAP_JIT bug on macOS
--- init_by_lua_block
    ngx.re.match('c', 'test', 'jo')
--- skip_eval
4: $^O ne 'darwin'
--- config
    location /re {
        content_by_lua_block {
            ngx.say(ngx.re.sub('c', 'a', 'b', ''))
            ngx.say(ngx.re.sub('c', 'a', 'b', 'jo'))
        }
    }
--- request
    GET /re
--- response_body
c0
c0
--- grep_error_log eval
qr/.+parse_regex_opts\(\): running regex in init phase under macOS,.+/
--- grep_error_log_out eval
qr/(:?.+parse_regex_opts\(\): running regex in init phase under macOS,.+){2}/s
--- no_error_log
[error]



=== TEST 2: PCRE MAP_JIT bug fix does not affect other OSes
--- init_by_lua_block
    ngx.re.match('c', 'test', 'jo')
--- skip_eval
4: $^O ne 'linux'
--- config
    location /re {
        content_by_lua_block {
            ngx.say(ngx.re.sub('c', 'a', 'b', ''))
            ngx.say(ngx.re.sub('c', 'a', 'b', 'jo'))
        }
    }
--- request
    GET /re
--- response_body
c0
c0
--- no_error_log
[error]
running regex in init phase under macOS
