# vim:set ft= ts=4 sw=4 et fdm=marker:
use Test::Nginx::Socket::Lua::Stream;
use Cwd qw(cwd);

plan tests => repeat_each() * (blocks() * 2 + 1);

my $pwd = cwd();

add_block_preprocessor(sub {
    my $block = shift;

    my $stream_config = $block->stream_config || '';

    $stream_config .= <<_EOC_;

    lua_package_path "$pwd/lib/?.lua;../lua-resty-lrucache/lib/?.lua;;";
_EOC_

    $block->set_value("stream_config", $stream_config);
});

no_shuffle();
use_hup();

$ENV{TEST_NGINX_BAR} = 'old';

run_tests();

__DATA__

=== TEST 1: env directive explicit value is visible within init_by_lua*
--- main_config
env FOO=old;
--- stream_config
    init_by_lua_block {
        require "resty.core"
        package.loaded.foo = os.getenv("FOO")
    }
--- stream_server_config
    content_by_lua_block {
        ngx.say(package.loaded.foo)
    }
--- stream_response
old
--- error_log
[notice]



=== TEST 2: HUP reload changes env value (1/3)
--- main_config
env FOO=new;
--- stream_config
    init_by_lua_block {
        require "resty.core"
        package.loaded.foo = os.getenv("FOO")
    }
--- stream_server_config
    content_by_lua_block {
        ngx.say(package.loaded.foo)
    }
--- stream_response
new



=== TEST 3: HUP reload changes env value (2/3)
--- main_config
env FOO=;
--- stream_config
    init_by_lua_block {
        require "resty.core"
        package.loaded.foo = os.getenv("FOO")
    }
--- stream_server_config
    content_by_lua_block {
        ngx.say(package.loaded.foo)
    }
--- stream_response_like chomp
\s



=== TEST 4: HUP reload changes env value (3/3)
--- main_config
env FOO;
--- stream_config
    init_by_lua_block {
        require "resty.core"
        package.loaded.foo = os.getenv("FOO")
    }
--- stream_server_config
    content_by_lua_block {
        ngx.say(package.loaded.foo)
    }
--- stream_response
nil



=== TEST 5: HUP reload changes visible environment variable (1/2)
--- main_config
env TEST_NGINX_BAR;
--- stream_config
    init_by_lua_block {
        require "resty.core"
        package.loaded.test_nginx_bar = os.getenv("TEST_NGINX_BAR")
    }
--- stream_server_config
    content_by_lua_block {
        ngx.say(package.loaded.test_nginx_bar)
    }
--- stream_response
old



=== TEST 6: HUP reload changes visible environment variable (2/2)
--- main_config
env TEST_NGINX_BAR=new;
--- stream_config
    init_by_lua_block {
        require "resty.core"
        package.loaded.test_nginx_bar = os.getenv("TEST_NGINX_BAR")
    }
--- stream_server_config
    content_by_lua_block {
        ngx.say(package.loaded.test_nginx_bar)
    }
--- stream_response
new
