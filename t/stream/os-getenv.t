# vim:set ft= ts=4 sw=4 et fdm=marker:
use lib '.';
use t::TestCore::Stream;

plan tests => repeat_each() * (blocks() * 2 + 2);

$ENV{TEST_NGINX_BAR} = 'world';
$ENV{TEST_NGINX_LUA_PACKAGE_PATH} = "$t::TestCore::Stream::lua_package_path";

run_tests();

__DATA__

=== TEST 1: env directive explicit value is visible within init_by_lua*
--- main_config
env FOO=hello;
--- stream_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";

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
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";
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
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";

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
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";

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
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";

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
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";

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
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";

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
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";
    lua_load_resty_core off;

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



=== TEST 9: os.getenv() can be localized before loading resty.core
--- main_config
env FOO=hello;
--- stream_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";
    lua_load_resty_core off;

    init_by_lua_block {
        package.loaded.os_getenv = os.getenv
        require "resty.core"

        do
            local getenv = os.getenv

            package.loaded.f = function ()
                ngx.log(ngx.NOTICE, "FOO: ", getenv("FOO"))
            end
        end

        package.loaded.f()

        package.loaded.is_os_getenv = os.getenv == package.loaded.os_getenv
    }
--- stream_server_config
    content_by_lua_block {
        package.loaded.f()
        package.loaded.f()

        ngx.say("in init: ", package.loaded.is_os_getenv, "\n",
                "in content: ", os.getenv == package.loaded.os_getenv)
    }
--- stream_response
in init: false
in content: true
--- grep_error_log eval
qr/FOO: [a-z]+/
--- grep_error_log_out
FOO: hello
FOO: hello
FOO: hello



=== TEST 10: os.getenv() can be localized after loading resty.core
--- main_config
env FOO=hello;
--- stream_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";
    lua_load_resty_core off;

    init_by_lua_block {
        package.loaded.os_getenv = os.getenv

        do
            local getenv = os.getenv

            package.loaded.f = function ()
                ngx.log(ngx.NOTICE, "FOO: ", getenv("FOO"))
            end
        end

        require "resty.core"

        package.loaded.f()

        package.loaded.is_os_getenv = os.getenv == package.loaded.os_getenv
    }
--- stream_server_config
    content_by_lua_block {
        package.loaded.f()
        package.loaded.f()

        ngx.say("in init: ", package.loaded.is_os_getenv, "\n",
                "in content: ", os.getenv == package.loaded.os_getenv)
    }
--- stream_response
in init: false
in content: false
--- grep_error_log eval
qr/FOO: [a-z]+/
--- grep_error_log_out
FOO: nil
FOO: hello
FOO: hello
