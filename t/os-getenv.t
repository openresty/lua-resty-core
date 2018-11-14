# vim:set ft= ts=4 sw=4 et fdm=marker:
use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

plan tests => repeat_each() * (blocks() * 3);

my $pwd = cwd();

add_block_preprocessor(sub {
    my $block = shift;

    my $http_config = $block->http_config || '';
    my $init_by_lua_block = $block->init_by_lua_block || 'require "resty.core"';

    $http_config .= <<_EOC_;
    lua_package_path "$pwd/lib/?.lua;../lua-resty-lrucache/lib/?.lua;;";
_EOC_

    $block->set_value("http_config", $http_config);

    if (!defined $block->error_log) {
        $block->set_value("no_error_log", "[error]");
    }

    if (!defined $block->request) {
        $block->set_value("request", "GET /t");
    }
});

$ENV{TEST_NGINX_BAR} = 'world';

run_tests();

__DATA__

=== TEST 1: env directive explicit value is visible within init_by_lua*
--- main_config
env FOO=hello;
--- http_config
    init_by_lua_block {
        require "resty.core"
        package.loaded.foo = os.getenv("FOO")
    }
--- config
location /t {
    content_by_lua_block {
        ngx.say(package.loaded.foo, "\n", os.getenv("FOO"))
    }
}
--- response_body
hello
hello



=== TEST 2: env directive explicit value is visible within init_by_lua* with lua_shared_dict
--- main_config
env FOO=hello;
--- http_config
    lua_shared_dict dogs 24k;

    init_by_lua_block {
        require "resty.core"
        package.loaded.foo = os.getenv("FOO")
    }
--- config
location /t {
    content_by_lua_block {
        ngx.say(package.loaded.foo, "\n", os.getenv("FOO"))
    }
}
--- response_body
hello
hello



=== TEST 3: env directive explicit value is case-sensitive within init_by_lua*
--- main_config
env FOO=hello;
--- http_config
    init_by_lua_block {
        require "resty.core"
        package.loaded.foo = os.getenv("foo")
    }
--- config
location /t {
    content_by_lua_block {
        ngx.say(package.loaded.foo, "\n", os.getenv("foo"))
    }
}
--- response_body
nil
nil



=== TEST 4: env directives with no value are ignored
--- main_config
env FOO;
--- http_config
    init_by_lua_block {
        require "resty.core"
        package.loaded.foo = os.getenv("FOO")
    }
--- config
location /t {
    content_by_lua_block {
        ngx.say(package.loaded.foo, "\n", os.getenv("FOO"))
    }
}
--- response_body
nil
nil



=== TEST 5: env is visible from environment
--- main_config
env TEST_NGINX_BAR;
--- http_config
    init_by_lua_block {
        require "resty.core"
        package.loaded.foo = os.getenv("TEST_NGINX_BAR")
    }
--- config
location /t {
    content_by_lua_block {
        ngx.say(package.loaded.foo, "\n", os.getenv("TEST_NGINX_BAR"))
    }
}
--- response_body
world
world



=== TEST 6: env explicit set vs environment set
--- main_config
env TEST_NGINX_BAR=goodbye;
--- http_config
    init_by_lua_block {
        require "resty.core"
        package.loaded.foo = os.getenv("TEST_NGINX_BAR")
    }
--- config
location /t {
    content_by_lua_block {
        ngx.say(package.loaded.foo, "\n", os.getenv("TEST_NGINX_BAR"))
    }
}
--- response_body
goodbye
goodbye



=== TEST 7: env directive with empty value
--- main_config
env FOO=;
--- http_config
    init_by_lua_block {
        require "resty.core"
        package.loaded.foo = os.getenv("FOO")
    }
--- config
location /t {
    content_by_lua_block {
        ngx.say("in init: ", package.loaded.foo, "\n",
                "in content: ", os.getenv("FOO"))
    }
}
--- response_body_like
in init:\s+
in content:\s+



=== TEST 8: os.getenv() overwrite is reverted in worker phases
--- http_config
    init_by_lua_block {
        package.loaded.os_getenv = os.getenv
        require "resty.core"
        package.loaded.is_os_getenv = os.getenv == package.loaded.os_getenv
    }
--- config
location /t {
    content_by_lua_block {
        os.getenv("")

        ngx.say("in init: ", package.loaded.is_os_getenv, "\n",
                "in content: ", os.getenv == package.loaded.os_getenv)
    }
}
--- response_body
in init: false
in content: true
