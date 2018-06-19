# vim:set ft= ts=4 sw=4 et fdm=marker:
use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

plan tests => repeat_each() * (blocks() * 4);

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
        $block->set_value("error_log",
                          qr/\[notice\] .*? \(SIGHUP\) received/);
    }

    if (!defined $block->no_error_log) {
        $block->set_value("no_error_log", "[error]");
    }

    if (!defined $block->request) {
        $block->set_value("request", "GET /t");
    }
});

no_shuffle();
use_hup();

$ENV{TEST_NGINX_BAR} = 'old';

run_tests();

__DATA__

=== TEST 1: env directive explicit value is visible within init_by_lua*
--- main_config
env FOO=old;
--- http_config
    init_by_lua_block {
        require "resty.core"
        package.loaded.foo = os.getenv("FOO")
    }
--- config
location /t {
    content_by_lua_block {
        ngx.say(package.loaded.foo)
    }
}
--- response_body
old
--- error_log
[notice]



=== TEST 2: HUP reload changes env value (1/3)
--- main_config
env FOO=new;
--- http_config
    init_by_lua_block {
        require "resty.core"
        package.loaded.foo = os.getenv("FOO")
    }
--- config
location /t {
    content_by_lua_block {
        ngx.say(package.loaded.foo)
    }
}
--- response_body
new



=== TEST 3: HUP reload changes env value (2/3)
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
        ngx.say(package.loaded.foo)
    }
}
--- response_body_like chomp
\s



=== TEST 4: HUP reload changes env value (3/3)
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
        ngx.say(package.loaded.foo)
    }
}
--- response_body
nil



=== TEST 5: HUP reload changes visible environment variable (1/2)
--- main_config
env TEST_NGINX_BAR;
--- http_config
    init_by_lua_block {
        require "resty.core"
        package.loaded.test_nginx_bar = os.getenv("TEST_NGINX_BAR")
    }
--- config
location /t {
    content_by_lua_block {
        ngx.say(package.loaded.test_nginx_bar)
    }
}
--- response_body
old



=== TEST 6: HUP reload changes visible environment variable (2/2)
--- main_config
env TEST_NGINX_BAR=new;
--- http_config
    init_by_lua_block {
        require "resty.core"
        package.loaded.test_nginx_bar = os.getenv("TEST_NGINX_BAR")
    }
--- config
location /t {
    content_by_lua_block {
        ngx.say(package.loaded.test_nginx_bar)
    }
}
--- response_body
new
