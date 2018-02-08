# vim:set ft= ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

repeat_each(2);

plan tests => repeat_each() * (blocks() * 5);

my $pwd = cwd();

our $HttpConfig = <<_EOC_;
    lua_package_path "$pwd/lib/?.lua;../lua-resty-lrucache/lib/?.lua;;";
_EOC_

env_to_nginx("TEST_NGINX_ENV=hello");

check_accum_error_log();
run_tests();

__DATA__

=== TEST 1: ngx_configure.is_configure_phase()
--- http_config eval
qq{
    configure_by_lua_block {
        local ngx_configure = require "ngx.configure"

        print("is configure: ", ngx_configure.is_configure_phase())
    }

    $::HttpConfig
}
--- config
    location = /t {
        content_by_lua_block {
            local ngx_configure = require "ngx.configure"

            ngx.say("is configure: ", ngx_configure.is_configure_phase())
        }
    }
--- request
GET /t
--- response_body
is configure: false
--- error_log
is configure: true
--- no_error_log
[error]
[alert]



=== TEST 2: configure_by_lua resty.core ngx.get_phase()
--- http_config eval
qq{
    configure_by_lua_block {
        require "resty.core.phase"

        print("phase: ", ngx.get_phase())
    }

    $::HttpConfig
}
--- config
    location = /t {
        return 200;
    }
--- request
GET /t
--- ignore_response_body
--- error_log
phase: configure
--- no_error_log
[error]
[alert]
[crit]



=== TEST 3: ngx_configure.shared_dict (invalid context)
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            local ngx_configure = require "ngx.configure"

            ngx_configure.shared_dict("dogs", "12k")
        }
    }
--- request
GET /t
--- error_code: 500
--- error_log eval
qr/\[error\] .*? content_by_lua\(nginx.conf:\d+\):\d+: API disabled in the current context/
--- no_error_log
[crit]
[alert]
[emerg]



=== TEST 4: ngx_configure.shared_dict (invalid arguments)
--- http_config eval
qq{
    configure_by_lua_block {
        local ngx_configure = require "ngx.configure"

        local pok, err = pcall(ngx_configure.shared_dict)
        if not pok then
            print(err)
        end
    }

    $::HttpConfig
}
--- config
    location /t {
        return 200;
    }
--- request
GET /t
--- error_log eval
qr/\[notice\] .*? configure_by_lua:\d+: name must be a string/
--- no_error_log
[crit]
[alert]
[emerg]



=== TEST 5: ngx_configure.shared_dict (invalid name)
--- http_config eval
qq{
    configure_by_lua_block {
        local ngx_configure = require "ngx.configure"

        ngx_configure.shared_dict("", "12k")
    }

    $::HttpConfig
}
--- config
    location /t {
        return 200;
    }
--- must_die
--- error_log eval
qr/\[error\] .*? configure_by_lua:\d+: invalid lua shared dict name/
--- no_error_log
[crit]
[alert]
[emerg]



=== TEST 6: ngx_configure.shared_dict (invalid size)
--- http_config eval
qq{
    configure_by_lua_block {
        local ngx_configure = require "ngx.configure"

        local pok, perr = pcall(ngx_configure.shared_dict, "dogs", "")
        if not pok then
            print("1: ", perr)
        end

        local pok, perr = pcall(ngx_configure.shared_dict, "dogs", "foo")
        if not pok then
            print("2: ", perr)
        end

        local pok, perr = pcall(ngx_configure.shared_dict, "dogs", "128")
        if not pok then
            print("3: ", perr)
        end
    }

    $::HttpConfig
}
--- config
    location /t {
        return 200;
    }
--- request
GET /t
--- error_log eval
[qr/\[notice\] .*? configure_by_lua:\d+: 1: invalid lua shared dict size/,
qr/\[notice\] .*? configure_by_lua:\d+: 2: invalid lua shared dict size "foo"/,
qr/\[notice\] .*? configure_by_lua:\d+: 3: invalid lua shared dict size "128"/]
--- no_error_log
[emerg]



=== TEST 7: ngx_configure.shared_dict (already defined)
--- http_config eval
qq{
    lua_shared_dict dogs 12k;

    configure_by_lua_block {
        local ngx_configure = require "ngx.configure"

        ngx_configure.shared_dict("dogs", "12k")
    }

    $::HttpConfig
}
--- config
    location /t {
        return 200;
    }
--- request
GET /t
--- must_die
--- error_log eval
qr/\[error\] .*? configure_by_lua:\d+: lua_shared_dict "dogs" is already defined as "dogs"/
--- no_error_log
[crit]
[alert]
[emerg]



=== TEST 8: ngx_configure.shared_dict (creates working shm)
--- http_config eval
qq{
    configure_by_lua_block {
        local ngx_configure = require "ngx.configure"

        ngx_configure.shared_dict("dogs", "12k")
    }

    $::HttpConfig
}
--- config
    location /t {
        content_by_lua_block {
            local dogs = ngx.shared.dogs

            dogs:set("foo", true)

            ngx.say("foo = ", dogs:get("foo"))
        }
    }
--- request
GET /t
--- response_body
foo = true
--- no_error_log
[crit]
[alert]
[emerg]



=== TEST 9: ngx_configure.shared_dict (delays init phase until shms are init)
--- http_config eval
qq{
    configure_by_lua_block {
        local ngx_configure = require "ngx.configure"

        ngx_configure.shared_dict("dogs_init", "12k")
    }

    init_by_lua_block {
        local dogs = ngx.shared.dogs_init

        dogs:set("foo", true)

        ngx.log(ngx.NOTICE, "foo = ", dogs:get("foo"))
    }

    $::HttpConfig
}
--- config
    location /t {
        return 200;
    }
--- request
GET /t
--- error_log eval
qr/\[notice\] .*? init_by_lua:\d+: foo = true/
--- no_error_log
[crit]
[alert]
[emerg]



=== TEST 10: ngx_configure.shared_dict (disables shm API in configure phase 1/2)
--- http_config eval
qq{
    configure_by_lua_block {
        local ngx_configure = require "ngx.configure"

        ngx_configure.shared_dict("dogs", "12k")

        ngx.shared.dogs:set("foo", true)
    }

    $::HttpConfig
}
--- config
    location /t {
        return 200;
    }
--- must_die
--- error_log eval
qr/\[error\] .*? configure_by_lua:\d+: API disabled in the context of configure_by_lua/
--- no_error_log
[crit]
[alert]
[emerg]



=== TEST 11: ngx_configure.shared_dict (disables shm API in configure phase 2/2)
--- http_config eval
qq{
    configure_by_lua_block {
        local ngx_configure = require "ngx.configure"

        ngx_configure.shared_dict("dogs", "12k")

        ngx.shared.dogs:get("foo")
    }

    $::HttpConfig
}
--- config
    location /t {
        return 200;
    }
--- must_die
--- error_log eval
qr/\[error\] .*? configure_by_lua:\d+: API disabled in the context of configure_by_lua/
--- no_error_log
[crit]
[alert]
[emerg]



=== TEST 12: ngx_configure.shared_dict (disables resty.core shm API in configure phase)
--- http_config eval
qq{
    configure_by_lua_block {
        local ngx_configure = require "ngx.configure"

        ngx_configure.shared_dict("dogs", "12k")

        -- TODO: requiring resty.core before creating shdicts would nullify
        -- the core/shdict.lua metatable overrides, since `next(ngx_shared)` is
        -- nil until we create shms. We should not allow resty.core in configure,
        -- or find a way to trigger the metatable overrides if it is required
        -- before any shm is created.
        require "resty.core"

        ngx.shared.dogs:get("foo")
    }

    $::HttpConfig
}
--- config
    location /t {
        return 200;
    }
--- must_die
--- error_log eval
qr/\[error\] .*? configure_by_lua:\d+: API disabled in the context of configure_by_lua/
--- no_error_log
[crit]
[alert]
[emerg]



=== TEST 13: ngx_configure.shared_dict (sanity with multiple static shms)
--- http_config eval
qq{
    lua_shared_dict cats 128k;
    lua_shared_dict dogs 128k;

    init_by_lua_block {
        assert(ngx.shared.cats:set("marry", "black"))
        assert(ngx.shared.dogs:incr("count", 1, 0))
    }

    $::HttpConfig
}
--- config
    location /t {
        content_by_lua_block {
            local cats = ngx.shared.cats
            local dogs = ngx.shared.dogs

            ngx.say("cats marry = ", cats:get("marry"))
            ngx.say("dogs count = ", dogs:get("count"))
        }
    }
--- request
GET /t
--- response_body
cats marry = black
dogs count = 1
--- no_error_log
[crit]
[alert]
[emerg]



=== TEST 14: ngx_configure.shared_dict (sanity with multiple dynamic shms)
--- http_config eval
qq{
    configure_by_lua_block {
        local ngx_configure = require "ngx.configure"

        ngx_configure.shared_dict("cats", "128k")
        ngx_configure.shared_dict("dogs", "128k")
    }

    init_by_lua_block {
        assert(ngx.shared.cats:set("marry", "black"))
        assert(ngx.shared.dogs:incr("count", 1, 0))
    }

    $::HttpConfig
}
--- config
    location /t {
        content_by_lua_block {
            local cats = ngx.shared.cats
            local dogs = ngx.shared.dogs

            ngx.say("cats marry = ", cats:get("marry"))
            ngx.say("dogs count = ", dogs:get("count"))
        }
    }
--- request
GET /t
--- response_body
cats marry = black
dogs count = 1
--- no_error_log
[crit]
[alert]
[emerg]



=== TEST 15: ngx_configure.shared_dict (sanity with multiple mixed shms)
--- http_config eval
qq{
    lua_shared_dict cats 128k;
    lua_shared_dict dogs 128k;

    configure_by_lua_block {
        local ngx_configure = require "ngx.configure"

        ngx_configure.shared_dict("my_shm", "128k")
    }

    init_by_lua_block {
        assert(ngx.shared.cats:set("marry", "black"))
        assert(ngx.shared.dogs:incr("count", 1, 0))
        assert(ngx.shared.my_shm:incr("count", 1, 127))
    }

    $::HttpConfig
}
--- config
    location /t {
        content_by_lua_block {
            local cats = ngx.shared.cats
            local dogs = ngx.shared.dogs
            local my_shm = ngx.shared.my_shm

            ngx.say("cats marry = ", cats:get("marry"))
            ngx.say("dogs count = ", dogs:get("count"))
            ngx.say("my_shm count = ", my_shm:get("count"))
        }
    }
--- request
GET /t
--- response_body
cats marry = black
dogs count = 1
my_shm count = 128
--- no_error_log
[crit]
[alert]
[emerg]



=== TEST 16: ngx_configure.max_pending_timers (sanity with 1)
--- http_config eval
qq{
    configure_by_lua_block {
        local ngx_configure = require "ngx.configure"

        ngx_configure.max_pending_timers(1)
    }

    $::HttpConfig
}
--- config
    location /t {
        content_by_lua_block {
            local ok, err = ngx.timer.at(10, function() end)
            if not ok then
                ngx.log(ngx.ERR, "failed to set timer 1: ", err)
                return
            end

            local ok, err = ngx.timer.at(10, function() end)
            if not ok then
                ngx.log(ngx.ERR, "failed to set timer 2: ", err)
                return
            end

            ngx.say("ok")
        }
    }
--- request
GET /t
--- ignore_response_body
--- error_log
failed to set timer 2: too many pending timers
--- no_error_log
[crit]
[alert]
[emerg]



=== TEST 17: ngx_configure.max_pending_timers (arg not number)
--- http_config eval
qq{
    configure_by_lua_block {
        local ngx_configure = require "ngx.configure"

        ngx_configure.max_pending_timers("foo")
    }

    $::HttpConfig
}
--- config
    location /t {
        return 200;
    }
--- request
GET /t
--- must_die
--- error_log eval
qr/\[error\] .*? configure_by_lua:\d+: n_timers must be a number/
--- no_error_log
[crit]
[alert]
[emerg]



=== TEST 18: ngx_configure.max_pending_timers (arg not positive)
--- http_config eval
qq{
    configure_by_lua_block {
        local ngx_configure = require "ngx.configure"

        ngx_configure.max_pending_timers(-1)
    }

    $::HttpConfig
}
--- config
    location /t {
        return 200;
    }
--- request
GET /t
--- must_die
--- error_log eval
qr/\[error\] .*? configure_by_lua:\d+: n_timers must be positive/
--- no_error_log
[crit]
[alert]
[emerg]



=== TEST 19: ngx_configure.max_pending_timers (invalid context)
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            local ngx_configure = require "ngx.configure"

            ngx_configure.max_pending_timers(1)
        }
    }
--- request
GET /t
--- error_code: 500
--- error_log eval
qr/\[error\] .*? content_by_lua\(nginx.conf:\d+\):\d+: API disabled in the current context/
--- no_error_log
[crit]
[alert]
[emerg]



=== TEST 20: ngx_configure.max_running_timers (sanity with 1)
--- http_config eval
qq{
    configure_by_lua_block {
        local ngx_configure = require "ngx.configure"

        ngx_configure.max_running_timers(1)
    }

    $::HttpConfig
}
--- config
    location /t {
        content_by_lua_block {
            local ok, err = ngx.timer.at(0, function() ngx.sleep(0.002) end)
            if not ok then
                ngx.log(ngx.ERR, "failed to set timer 1: ", err)
                return
            end

            local ok, err = ngx.timer.at(0, function() end)
            if not ok then
                ngx.log(ngx.ERR, "failed to set timer 2: ", err)
                return
            end

            ngx.sleep(0.001)

            ngx.say("ok")
        }
    }
--- request
GET /t
--- ignore_response_body
--- error_log eval
qr/\[alert\] .*? 1 lua_max_running_timers are not enough/
--- no_error_log
[crit]
[error]
[emerg]



=== TEST 21: ngx_configure.max_running_timers (arg not number)
--- http_config eval
qq{
    configure_by_lua_block {
        local ngx_configure = require "ngx.configure"

        ngx_configure.max_running_timers("foo")
    }

    $::HttpConfig
}
--- config
    location /t {
        return 200;
    }
--- request
GET /t
--- must_die
--- error_log eval
qr/\[error\] .*? configure_by_lua:\d+: n_timers must be a number/
--- no_error_log
[crit]
[alert]
[emerg]



=== TEST 22: ngx_configure.max_running_timers (arg not positive)
--- http_config eval
qq{
    configure_by_lua_block {
        local ngx_configure = require "ngx.configure"

        ngx_configure.max_running_timers(-1)
    }

    $::HttpConfig
}
--- config
    location /t {
        return 200;
    }
--- request
GET /t
--- must_die
--- error_log eval
qr/\[error\] .*? configure_by_lua:\d+: n_timers must be positive/
--- no_error_log
[crit]
[alert]
[emerg]



=== TEST 23: ngx_configure.max_running_timers (invalid context)
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            local ngx_configure = require "ngx.configure"

            ngx_configure.max_running_timers(1)
        }
    }
--- request
GET /t
--- error_code: 500
--- error_log eval
qr/\[error\] .*? content_by_lua\(nginx.conf:\d+\):\d+: API disabled in the current context/
--- no_error_log
[crit]
[alert]
[emerg]



=== TEST 24: ngx_configure.env (invalid context)
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            local ngx_configure = require "ngx.configure"

            ngx_configure.env("FOO")
        }
    }
--- request
GET /t
--- error_code: 500
--- error_log eval
qr/\[error\] .*? content_by_lua\(nginx.conf:\d+\):\d+: API disabled in the current context/
--- no_error_log
[crit]
[alert]
[emerg]



=== TEST 25: ngx_configure.env (sanity)
--- http_config eval
qq{
    configure_by_lua_block {
        local ngx_configure = require "ngx.configure"

        ngx_configure.env("TEST_NGINX_ENV")
    }

    $::HttpConfig
}
--- config
    location /t {
        content_by_lua_block {
            ngx.say("TEST_NGINX_ENV: ", os.getenv("TEST_NGINX_ENV"))
        }
    }
--- request
GET /t
--- response_body
TEST_NGINX_ENV: hello
--- no_error_log
[crit]
[alert]
[emerg]



=== TEST 26: ngx_configure.env (with set env variable)
--- http_config eval
qq{
    configure_by_lua_block {
        local ngx_configure = require "ngx.configure"

        ngx_configure.env("TEST_NGINX_ENV_SET=foo")
    }

    $::HttpConfig
}
--- config
    location /t {
        content_by_lua_block {
            ngx.say("TEST_NGINX_ENV_SET: ", os.getenv("TEST_NGINX_ENV_SET"))
        }
    }
--- request
GET /t
--- response_body
TEST_NGINX_ENV_SET: foo
--- no_error_log
[crit]
[alert]
[emerg]



=== TEST 27: ngx_configure.env (invalid arg)
--- http_config eval
qq{
    configure_by_lua_block {
        local ngx_configure = require "ngx.configure"

        ngx_configure.env(123)
    }

    $::HttpConfig
}
--- config
    location /t {
        content_by_lua_block {
            ngx.say("TEST_NGINX_ENV_SET: ", os.getenv("TEST_NGINX_ENV_SET"))
        }
    }
--- request
GET /t
--- must_die
--- error_log eval
qr/\[error\] .*? configure_by_lua:\d+: value must be a string/
--- no_error_log
[crit]
[alert]
[emerg]
