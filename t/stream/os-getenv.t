# vim:set ft= ts=4 sw=4 et fdm=marker:
use Test::Nginx::Socket::Lua::Stream;
use Cwd qw(cwd);

plan tests => repeat_each() * (blocks() * 2);

my $pwd = cwd();

add_block_preprocessor(sub {
    my $block = shift;

    my $stream_config = $block->stream_config || '';

    $stream_config .= <<_EOC_;

    lua_package_path "$pwd/lib/?.lua;../lua-resty-lrucache/lib/?.lua;;";
_EOC_

    $block->set_value("stream_config", $stream_config);
});


$ENV{TEST_NGINX_BAR} = 'world';

run_tests();

__DATA__

=== TEST 1: env directive explicit value is visible within init_by_lua*
--- main_config
env FOO=hello;
--- stream_config
    init_by_lua_block {
        require "resty.core"
        package.loaded.foo = os.getenv("FOO")
    }
--- stream_server_config
    content_by_lua_block {
        ngx.say(package.loaded.foo, "\n", os.getenv("FOO"))
    }
--- stream_response
hello
hello



=== TEST 2: env directive explicit value is visible within init_by_lua* with lua_shared_dict
--- main_config
env FOO=hello;
--- stream_config
    lua_shared_dict dogs 24k;

    init_by_lua_block {
        require "resty.core"
        package.loaded.foo = os.getenv("FOO")
    }
--- stream_server_config
    content_by_lua_block {
        ngx.say(package.loaded.foo, "\n", os.getenv("FOO"))
    }
--- stream_response
hello
hello



=== TEST 3: env directive explicit value is case-sensitive within init_by_lua*
--- main_config
env FOO=hello;
--- stream_config
    init_by_lua_block {
        require "resty.core"
        package.loaded.foo = os.getenv("foo")
    }
--- stream_server_config
    content_by_lua_block {
        ngx.say(package.loaded.foo, "\n", os.getenv("foo"))
    }
--- stream_response
nil
nil



=== TEST 4: env directives with no value are ignored
--- main_config
env FOO;
--- stream_config
    init_by_lua_block {
        require "resty.core"
        package.loaded.foo = os.getenv("FOO")
    }
--- stream_server_config
    content_by_lua_block {
        ngx.say(package.loaded.foo, "\n", os.getenv("FOO"))
    }
--- stream_response
nil
nil



=== TEST 5: env is visible from environment
--- main_config
env TEST_NGINX_BAR;
--- stream_config
    init_by_lua_block {
        require "resty.core"
        package.loaded.foo = os.getenv("TEST_NGINX_BAR")
    }
--- stream_server_config
    content_by_lua_block {
        ngx.say(package.loaded.foo, "\n", os.getenv("TEST_NGINX_BAR"))
    }
--- stream_response
world
world



=== TEST 6: env explicit set vs environment set
--- main_config
env TEST_NGINX_BAR=goodbye;
--- stream_config
    init_by_lua_block {
        require "resty.core"
        package.loaded.foo = os.getenv("TEST_NGINX_BAR")
    }
--- stream_server_config
    content_by_lua_block {
        ngx.say(package.loaded.foo, "\n", os.getenv("TEST_NGINX_BAR"))
    }
--- stream_response
goodbye
goodbye



=== TEST 7: env directive with empty value
--- main_config
env FOO=;
--- stream_config
    init_by_lua_block {
        require "resty.core"
        package.loaded.foo = os.getenv("FOO")
    }
--- stream_server_config
    content_by_lua_block {
        ngx.say("in init: ", package.loaded.foo, "\n",
                "in content: ", os.getenv("FOO"))
    }
--- stream_response_like
in init:\s+
in content:\s+



=== TEST 8: os.getenv() overwrite is reverted in worker phases
--- stream_config
    init_by_lua_block {
        package.loaded.os_getenv = os.getenv
        require "resty.core"
        package.loaded.is_os_getenv = os.getenv == package.loaded.os_getenv
    }
--- stream_server_config
    content_by_lua_block {
        os.getenv("")

        ngx.say("in init: ", package.loaded.is_os_getenv, "\n",
                "in content: ", os.getenv == package.loaded.os_getenv)
    }
--- stream_response
in init: false
in content: true
