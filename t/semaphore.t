# vim:set ft=ts=4 sw=4 et fdm=marker:
use lib 'lib';
use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

#worker_connections(10140);
workers(1);
#log_level('warn');

repeat_each(2);

plan tests => repeat_each() * (blocks() * 3 + 1);

my $pwd = cwd();

no_long_string();
#no_diff();
$ENV{TEST_NGINX_LUA_PACKAGE_PATH} = "\"$pwd/ngx/?.lua;;\"";
#my $lua_default_lib = "/usr/local/openresty/lualib/?.lua";
our $HttpConfig = <<_EOC_;
    lua_package_path "$pwd/ngx/?.lua;;";
_EOC_

run_tests();

__DATA__

=== TEST 1: basic semaphore wait post in subrequest
--- http_config eval: $::HttpConfig
--- config
    location = /test {
        content_by_lua_block {
            local res1, res2 = ngx.location.capture_multi{
                { "/sem_wait"},
                { "/sem_post"},
            }
            ngx.say(res1.status)
            ngx.say(res1.body)
            ngx.say(res2.status)
            ngx.say(res2.body)
        }
    }

    location /sem_wait {
        content_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local g = package.loaded["semaphore_test"] or {}
            package.loaded["semaphore_test"] = g

            if not g.test then
                local sem, err = semaphore.new(0)
                if not sem then
                    ngx.say(err)
                    return
                end
                g.test = sem
            end
            local sem = g.test
            local ok, err = sem:wait(1)
            if ok then
                ngx.print("wait")
            end
        }
    }

    location /sem_post {
        content_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local g = package.loaded["semaphore_test"] or {}
            package.loaded["semaphore_test"] = g

            if not g.test then
                local sem, err = semaphore.new(0)
                if not sem then
                    ngx.say(err)
                    ngx.exit(500)
                end
                g.test = sem
            end
            local sem = g.test
            ngx.sleep(0.001)
            collectgarbage("collect")
            local ok, err = sem:post()
            if ok then
                ngx.print("post")
            else
                ngx.exit(500)
            end
        }
    }
--- request
GET /test
--- response_body
200
wait
200
post
--- no_error_log
[error]
[crit]



=== TEST 2: semaphore new not allowed in init_by_lua
--- http_config
    lua_package_path $TEST_NGINX_LUA_PACKAGE_PATH;
    init_by_lua_block {
        local semaphore = require "ngx.semaphore"
        local sem, err = semaphore.new(0)
        if not sem then
            ngx.log(ngx.ERR, err)
        else
            ngx.log(ngx.ERR, tostring(sem))
        end
    }
--- config
    location /test {
        echo "ok";
    }
--- request
GET /test
--- response_body
ok
--- grep_error_log eval: qr/API disabled in the context of init/
--- grep_error_log_out eval
[
"API disabled in the context of init
",
"",
]



=== TEST 3: semaphore in init_worker_by_lua (wait is not allowed)
--- http_config
    lua_package_path $TEST_NGINX_LUA_PACKAGE_PATH;
    init_worker_by_lua_block {
        local semaphore = require "ngx.semaphore"
        local sem, err = semaphore.new(0)
        if not sem then
            ngx.log(ngx.ERR, "sem: ", err)
        end

        local ok, err = sem:post(1)
        if not ok then
            ngx.log(ngx.ERR, "sem: ", err)
        end

        local count = sem:count()
        ngx.log(ngx.ERR, "sem: ", count)

        local ok, err = sem:wait(0.1)
        if not ok then
            ngx.log(ngx.ERR, "sem: ", err)
        end
    }
--- config
    location /t {
        echo "ok";
    }
--- request
GET /t
--- response_body
ok
--- grep_error_log eval: qr/sem: .*?,/
--- grep_error_log_out eval
[
"sem: 1,
sem: API disabled in the context of init_worker_by_lua*,
",
"",
]



=== TEST 4: semaphore in set_by_lua (wait is not allowed)
--- http_config eval: $::HttpConfig
--- config
    location /t {
        set_by_lua_block $res {
            local semaphore = require "ngx.semaphore"
            local sem, err = semaphore.new(0)
            if not sem then
                ngx.log(ngx.ERR, "sem: ", err)
            end

            local ok, err = sem:post(1)
            if not ok then
                ngx.log(ngx.ERR, "sem: ", err)
            end

            local count = sem:count()
            ngx.log(ngx.ERR, "sem: ", count)

            local ok, err = sem:wait(0.1)
            if not ok then
                ngx.log(ngx.ERR, "sem: ", err)
            end
        }
        echo "ok";
    }
--- request
GET /t
--- response_body
ok
--- grep_error_log eval: qr/sem: .*?,/
--- grep_error_log_out eval
[
"sem: 1,
sem: API disabled in the context of set_by_lua*,
",
"sem: 1,
sem: API disabled in the context of set_by_lua*,
",
]



=== TEST 5: semaphore in rewrite_by_lua (all allowed)
--- http_config eval: $::HttpConfig
--- config
    location /t {
        rewrite_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local sem, err = semaphore.new(0)
            if not sem then
                ngx.log(ngx.ERR, "sem: ", err)
            end

            local ok, err = sem:wait(0.01)
            if not ok then
                ngx.log(ngx.ERR, "sem: ", err)
            end

            local ok, err = sem:post(1)
            if not ok then
                ngx.log(ngx.ERR, "sem: ", err)
            end

            local count = sem:count()
            ngx.log(ngx.ERR, "sem: ", count)

            local ok, err = sem:wait(0.1)
            if not ok then
                ngx.log(ngx.ERR, "sem: ", err)
            end
        }
        echo "ok";
    }
--- request
GET /t
--- response_body
ok
--- grep_error_log eval: qr/sem: .*?,/
--- grep_error_log_out eval
[
"sem: timeout,
sem: 1,
",
"sem: timeout,
sem: 1,
",
]



=== TEST 6: semaphore in access_by_lua (all allowed)
--- http_config eval: $::HttpConfig
--- config
    location /t {
        access_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local sem, err = semaphore.new(0)
            if not sem then
                ngx.log(ngx.ERR, "sem: ", err)
            end

            local ok, err = sem:wait(0.01)
            if not ok then
                ngx.log(ngx.ERR, "sem: ", err)
            end

            local ok, err = sem:post(1)
            if not ok then
                ngx.log(ngx.ERR, "sem: ", err)
            end

            local count = sem:count()
            ngx.log(ngx.ERR, "sem: ", count)

            local ok, err = sem:wait(0.1)
            if not ok then
                ngx.log(ngx.ERR, "sem: ", err)
            end
        }
        echo "ok";
    }
--- request
GET /t
--- response_body
ok
--- grep_error_log eval: qr/sem: .*?,/
--- grep_error_log_out eval
[
"sem: timeout,
sem: 1,
",
"sem: timeout,
sem: 1,
",
]



=== TEST 7: semaphore in content_by_lua (all allowed)
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local sem, err = semaphore.new(0)
            if not sem then
                ngx.log(ngx.ERR, "sem: ", err)
            end

            local ok, err = sem:wait(0.01)
            if not ok then
                ngx.log(ngx.ERR, "sem: ", err)
            end

            local ok, err = sem:post(1)
            if not ok then
                ngx.log(ngx.ERR, "sem: ", err)
            end

            local count = sem:count()
            ngx.log(ngx.ERR, "sem: ", count)

            local ok, err = sem:wait(0.1)
            if not ok then
                ngx.log(ngx.ERR, "sem: ", err)
            else
                ngx.say("ok")
            end
        }
    }
--- request
GET /t
--- response_body
ok
--- grep_error_log eval: qr/sem: .*?,/
--- grep_error_log_out eval
[
"sem: timeout,
sem: 1,
",
"sem: timeout,
sem: 1,
",
]



=== TEST 8: semaphore in log_by_lua (wait not allowed)
--- http_config eval: $::HttpConfig
--- config
    location /t {
        echo "ok";
        log_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local sem, err = semaphore.new(0)
            if not sem then
                ngx.log(ngx.ERR, "sem: ", err)
            end

            local ok, err = sem:post(1)
            if not ok then
                ngx.log(ngx.ERR, "sem: ", err)
            end

            local count = sem:count()
            ngx.log(ngx.ERR, "sem: ", count)

            local ok, err = sem:wait(0.1)
            if not ok then
                ngx.log(ngx.ERR, "sem: ", err)
            end
        }
    }
--- request
GET /t
--- response_body
ok
--- grep_error_log eval: qr/sem: .*?,/
--- grep_error_log_out eval
[
"sem: 1 while logging request,
sem: API disabled in the context of log_by_lua* while logging request,
",
"sem: 1 while logging request,
sem: API disabled in the context of log_by_lua* while logging request,
",
]



=== TEST 9: semaphore in header_filter_by_lua (wait not allowed)
--- http_config eval: $::HttpConfig
--- config
    location /t {
        echo "ok";
        header_filter_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local sem, err = semaphore.new(0)
            if not sem then
                ngx.log(ngx.ERR, "sem: ", err)
            end

            local ok, err = sem:post(1)
            if not ok then
                ngx.log(ngx.ERR, "sem: ", err)
            end

            local count = sem:count()
            ngx.log(ngx.ERR, "sem: ", count)

            local ok, err = sem:wait(0.1)
            if not ok then
                ngx.log(ngx.ERR, "sem: ", err)
            end
        }
    }
--- request
GET /t
--- response_body
ok
--- grep_error_log eval: qr/sem: .*?,/
--- grep_error_log_out eval
[
"sem: 1,
sem: API disabled in the context of header_filter_by_lua*,
",
"sem: 1,
sem: API disabled in the context of header_filter_by_lua*,
",
]



=== TEST 10: semaphore in body_filter_by_lua (wait not allowed)
--- http_config eval: $::HttpConfig
--- config
    location /t {
        echo "ok";
        body_filter_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local sem, err = semaphore.new(0)
            if not sem then
                ngx.log(ngx.ERR, "sem: ", err)
            end

            local ok, err = sem:post(1)
            if not ok then
                ngx.log(ngx.ERR, "sem: ", err)
            end

            local count = sem:count()
            ngx.log(ngx.ERR, "sem: ", count)

            local ok, err = sem:wait(0.1)
            if not ok then
                ngx.log(ngx.ERR, "sem: ", err)
            end
        }
    }
--- request
GET /t
--- response_body
ok
--- grep_error_log eval: qr/sem: .*?,/
--- grep_error_log_out eval
[
"sem: 1,
sem: API disabled in the context of body_filter_by_lua*,
sem: 1,
sem: API disabled in the context of body_filter_by_lua*,
",
"sem: 1,
sem: API disabled in the context of body_filter_by_lua*,
sem: 1,
sem: API disabled in the context of body_filter_by_lua*,
",
]



=== TEST 11: semaphore in ngx.timer (all allowed)
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            local function func_sem()
                local semaphore = require "ngx.semaphore"
                local sem, err = semaphore.new(0)
                if not sem then
                    ngx.log(ngx.ERR, "sem: ", err)
                end

                local ok, err = sem:wait(0.01)
                if not ok then
                    ngx.log(ngx.ERR, "sem: ", err)
                end

                local ok, err = sem:post(1)
                if not ok then
                    ngx.log(ngx.ERR, "sem: ", err)
                end

                local count = sem:count()
                ngx.log(ngx.ERR, "sem: ", count)

                local ok, err = sem:wait(0.1)
                if not ok then
                    ngx.log(ngx.ERR, "sem: ", err)
                end
            end

            local ok, err = ngx.timer.at(0, func_sem)
            if ok then
                ngx.sleep(0.01)
                ngx.say("ok")
            end
        }
    }
--- request
GET /t
--- response_body
ok
--- grep_error_log eval: qr/sem: .*?,/
--- grep_error_log_out eval
[
"sem: timeout,
sem: 1,
",
"sem: timeout,
sem: 1,
",
]



=== TEST 12: semaphore post in all phase (in a request)
--- http_config
    lua_package_path $TEST_NGINX_LUA_PACKAGE_PATH;
    init_worker_by_lua_block {
        local semaphore = require "ngx.semaphore"
        local sem, err = semaphore.new(0)
        if not sem then
            ngx.log(ngx.ERR, err)
        end
        package.loaded.sem = sem

        local function wait()
            local i = 0
            while true do
                local ok, err = sem:wait(1)
                if not ok then
                    ngx.log(ngx.ERR, "sem: ", err)
                end
                i = i + 1
                if i % 6 == 0 then
                    ngx.log(ngx.ERR, "sem: 6 times")
                end
            end
        end

        local ok, err = ngx.timer.at(0, wait)
        if not ok then
            ngx.log(ngx.ERR, "sem: ", err)
        end
    }
--- config
    location /test {
        set_by_lua_block $res {
            local sem = package.loaded.sem
            sem:post()
        }
        rewrite_by_lua_block {
            local sem = package.loaded.sem
            sem:post()
        }
        access_by_lua_block {
            local sem = package.loaded.sem
            sem:post()
        }
        content_by_lua_block {
            local sem = package.loaded.sem
            local ok, err = sem:post()
            if ok then
                ngx.say("ok")
            end
        }
        header_filter_by_lua_block {
            local sem = package.loaded.sem
            sem:post()
        }
        body_filter_by_lua_block {
            local sem = package.loaded.sem
            sem:post()
        }
    }
--- request
GET /test
--- response_body
ok
--- grep_error_log eval: qr/sem: .*?,/
--- grep_error_log_out eval
[
"sem: 6 times,
",
"sem: 6 times,
",
]



=== TEST 13: semaphore wait post in access_by_lua
--- http_config eval: $::HttpConfig
--- config
    location /test {
        access_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local sem = semaphore.new(0)

            local func_wait = function ()
                ngx.say("enter wait")

                local ok, err = sem:wait(1)
                if ok then
                    ngx.say("wait success")
                end
            end
            local func_post = function ()
                ngx.say("enter post")

                local ok, err = sem:post()
                if ok then
                    ngx.say("post success")
                end
            end

            local co1 = ngx.thread.spawn(func_wait)
            local co2 = ngx.thread.spawn(func_post)

            ngx.thread.wait(co1)
            ngx.thread.wait(co2)
        }
    }
--- request
GET /test
--- response_body
enter wait
enter post
post success
wait success
--- no_error_log
[error]



=== TEST 14: semaphore wait post in rewrite_by_lua
--- http_config eval: $::HttpConfig
--- config
    location /t {
        rewrite_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local sem = semaphore.new(0)

            local func_wait = function ()
                ngx.say("enter wait")

                local ok, err = sem:wait(1)
                if ok then
                    ngx.say("wait success")
                end
            end
            local func_post = function ()
                ngx.say("enter post")

                local ok, err = sem:post()
                if ok then
                    ngx.say("post success")
                end
            end

            local co1 = ngx.thread.spawn(func_wait)
            local co2 = ngx.thread.spawn(func_post)

            ngx.thread.wait(co1)
            ngx.thread.wait(co2)
        }
    }
--- request
GET /test
--- response_body
enter wait
enter post
post success
wait success
--- no_error_log
[error]



=== TEST 15: semaphore wait in timer.at
--- http_config eval: $::HttpConfig
--- config
    location /test {
        content_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local sem = semaphore.new(1)

            local function func_wait(premature)
                local ok, err = sem:wait(1)
                if not ok then
                    ngx.log(ngx.ERR, err)
                else
                    ngx.log(ngx.ERR, "wait success")
                end
            end

            ngx.timer.at(0, func_wait)
            ngx.sleep(0.01)
            ngx.say("ok")
        }
    }
--- request
GET /test
--- response_body
ok
--- error_log
wait success



=== TEST 16: semaphore post in header_filter_by_lua (subrequest)
--- http_config eval: $::HttpConfig
--- config
    location /test {
        content_by_lua_block {
            local res1, res2 = ngx.location.capture_multi{
                {"/sem_wait"},
                {"/sem_post"},
            }
            ngx.say(res1.status)
            ngx.say(res1.body)
            ngx.say(res2.status)
            ngx.say(res2.body)
        }
    }

    location /sem_wait {
        content_by_lua_block {
            local semaphore = require "ngx.semaphore"
            if not package.loaded.sem then
                local sem, err = semaphore.new(0)
                if not sem then
                    ngx.say(err)
                    ngx.exit(500)
                end
                package.loaded.sem = sem
            end
            local sem = package.loaded.sem
            local ok, err = sem:wait(1)
            if ok then
                ngx.print("wait")
                ngx.exit(200)
            else
                ngx.exit(500)
            end
        }
    }

    location /sem_post {
        header_filter_by_lua_block {
            local semaphore = require "ngx.semaphore"
            if not package.loaded.sem then
                local sem, err = semaphore.new(0)
                if not sem then
                    ngx.log(ngx.ERR, err)
                end
                package.loaded.sem = sem
            end
            local sem = package.loaded.sem
            local ok, err = sem:post()
            if not ok then
                ngx.log(ngx.ERR, err)
            end
        }

        content_by_lua_block {
            ngx.print("post")
            ngx.exit(200)
        }
    }
--- request
GET /test
--- response_body
200
wait
200
post
--- no_error_log
[error]



=== TEST 17: semaphore post in body_filter_by_lua (subrequest)
--- http_config eval: $::HttpConfig
--- config
    location /test {
        content_by_lua_block {
            local res1, res2 = ngx.location.capture_multi{
                {"/sem_wait"},
                {"/sem_post"},
            }
            ngx.say(res1.status)
            ngx.say(res1.body)
            ngx.say(res2.status)
            ngx.say(res2.body)
        }
    }

    location /sem_wait {
        content_by_lua_block {
            local semaphore = require "ngx.semaphore"
            if not package.loaded.sem then
                local sem, err = semaphore.new(0)
                if not sem then
                    ngx.say(err)
                    ngx.exit(500)
                end
                package.loaded.sem = sem
            end
            local sem = package.loaded.sem
            local ok, err = sem:wait(10)
            if ok then
                ngx.print("wait")
                ngx.exit(200)
            else
                ngx.exit(500)
            end
        }
    }

    location /sem_post {
        body_filter_by_lua_block {
            local semaphore = require "ngx.semaphore"
            if not package.loaded.sem then
                local sem, err = semaphore.new(0)
                if not sem then
                    ngx.log(ngx.ERR, err)
                end
                package.loaded.sem = sem
            end
            local sem = package.loaded.sem
            local ok, err = sem:post()
            if not ok then
                ngx.log(ngx.ERR, err)
            end
        }

        content_by_lua_block {
            ngx.print("post")
            ngx.exit(200)
        }
    }
--- request
GET /test
--- response_body
200
wait
200
post
--- log_level: debug
--- no_error_log
[error]



=== TEST 19: semaphore post in set_by_lua
--- http_config eval: $::HttpConfig
--- config
    location /test {
        content_by_lua_block {
            local res1, res2 = ngx.location.capture_multi{
                {"/sem_wait"},
                {"/sem_post"},
            }
            ngx.say(res1.status)
            ngx.say(res1.body)
            ngx.say(res2.status)
            ngx.say(res2.body)
        }
    }

    location /sem_wait {
        content_by_lua_block {
            local semaphore = require "ngx.semaphore"
            if not package.loaded.sem then
                local sem, err = semaphore.new(0)
                if not sem then
                    ngx.say(err)
                    ngx.exit(500)
                end
                package.loaded.sem = sem
            end
            local sem = package.loaded.sem
            local ok, err = sem:wait(10)
            if ok then
                ngx.print("wait")
                ngx.exit(200)
            else
                ngx.exit(500)
            end
        }
    }

    location /sem_post {
        set_by_lua_block $res {
            local semaphore = require "ngx.semaphore"
            if not package.loaded.sem then
                local sem, err = semaphore.new(0)
                if not sem then
                    ngx.log(ngx.ERR, err)
                end
                package.loaded.sem = sem
            end
            local sem = package.loaded.sem
            local ok, err = sem:post()
            if not ok then
                ngx.log(ngx.ERR, err)
            end
        }
        content_by_lua_block {
            ngx.print("post")
            ngx.exit(200)
        }
    }
--- request
GET /test
--- response_body
200
wait
200
post
--- log_level: debug
--- no_error_log
[error]



=== TEST 20: semaphore post in timer.at
--- http_config eval: $::HttpConfig
--- config
    location /test {
        content_by_lua_block {
            local semaphore = require "ngx.semaphore"
            package.loaded.sem = semaphore.new(0)
            local res1, res2 = ngx.location.capture_multi{
                {"/sem_wait"},
                {"/sem_post"},
            }
            ngx.say(res1.status)
            ngx.say(res1.body)
            ngx.say(res2.status)
            ngx.say(res2.body)
        }
    }

    location /sem_wait {
        content_by_lua_block {
            local sem = package.loaded.sem
            local ok, err = sem:wait(2)
            if ok then
                ngx.print("wait")
                ngx.exit(200)
            else
                ngx.status = 500
                ngx.say(err)
            end
        }
    }

    location /sem_post {
        content_by_lua_block {
            local function func(premature)
                local sem = package.loaded.sem
                local ok, err = sem:post()
                if not ok then
                    ngx.log(ngx.ERR, err)
                end
            end
            ngx.timer.at(0, func, g)
            ngx.sleep(0)
            ngx.print("post")
            ngx.exit(200)
        }
    }
--- request
GET /test
--- response_body
200
wait
200
post
--- log_level: debug
--- no_error_log
[error]



=== TEST 21: kill a light thread that is waiting on a semaphore(no resource)
--- http_config eval: $::HttpConfig
--- config
    location /test {
        content_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local sem = semaphore.new(0)
            if not sem then
                error("create failed")
            end

            local function func_wait()
                sem:wait(1)
            end
            local co = ngx.thread.spawn(func_wait)
            local ok, err = ngx.thread.kill(co)
            if ok then
                ngx.say("ok")
            else
                ngx.say(err)
            end
        }
    }
--- log_level: debug
--- request
GET /test
--- response_body
ok
--- no_error_log
[error]



=== TEST 22: kill a light thread that is waiting on a semaphore(after post)
--- http_config eval: $::HttpConfig
--- config
    location /test {
        content_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local sem = semaphore.new(0)
            if not sem then
                error("create failed")
            end

            local function func_wait()
                sem:wait(1)
            end
            local co = ngx.thread.spawn(func_wait)

            sem:post()
            local ok, err = ngx.thread.kill(co)

            if ok then
                ngx.say("ok")
            else
                ngx.say(err)
            end

            ngx.sleep(0.001)

            local count = sem:count()
            ngx.say("count: ", count)
        }
    }
--- log_level: debug
--- request
GET /test
--- response_body
ok
count: 1
--- no_error_log
[error]



=== TEST 23: a light thread that is going to exit is waiting on a semaphore
--- http_config eval: $::HttpConfig
--- config
    location /test {
        content_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local sem = semaphore.new(0)
            if not sem then
                error("create failed")
            end
            local function func(sem)
                local ok, err = sem:wait(0.001)
                if ok then
                    ngx.say("wait success")
                else
                    ngx.say("err: ", err)
                end
            end
            local co = ngx.thread.spawn(func, sem)
            ngx.say("ok")
            ngx.exit(200)
        }
    }
--- log_level: debug
--- request
GET /test
--- response_body
ok
--- error_log
http lua semaphore cleanup



=== TEST 24: main thread wait a light thread that is waiting on a semaphore
--- http_config eval: $::HttpConfig
--- config
    location /test {
        content_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local sem = semaphore.new(0)
            if not sem then
                error("create failed")
            end
            local function func(sem)
                local ok, err = sem:wait(0.001)
                if ok then
                    ngx.say("wait success")
                else
                    ngx.say("err: ", err)
                end
            end
            local co = ngx.thread.spawn(func, sem)
            ngx.thread.wait(co)
        }
    }
--- log_level: debug
--- request
GET /test
--- response_body
err: timeout
--- no_error_log
[error]



=== TEST 25: multi wait and mult post with one semaphore
--- http_config eval: $::HttpConfig
--- config
    location = /test {
        content_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local sem, err = semaphore.new(0)
            if not sem then
                ngx.log(ngx.ERR, err)
                ngx.exit(500)
            end

            local function func(op, id)
                ngx.say(op, ": ", id)
                if op == "wait" then
                    local ok, err = sem:wait(1)
                    if ok then
                        ngx.say("wait success: ", id)
                    end
                else
                    local ok, err = sem:post()
                    if not ok then
                        ngx.say("post err: ", err)
                    end
                end
            end
            local tco = {}

            for i = 1, 3 do
                tco[#tco + 1] = ngx.thread.spawn(func, "wait", i)
            end

            for i = 1, 3 do
                tco[#tco + 1] = ngx.thread.spawn(func, "post", i)
            end

            for i = 1, #tco do
                ngx.thread.wait(tco[i])
            end
        }
    }
--- request
GET /test
--- response_body
wait: 1
wait: 2
wait: 3
post: 1
post: 2
post: 3
wait success: 1
wait success: 2
wait success: 3
--- no_error_log
[error]



=== TEST 26: semaphore wait time is zero
--- http_config eval: $::HttpConfig
--- config
    location /test {
        content_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local sem = semaphore.new(0)
            local ok, err = sem:wait(0)
            if not ok then
                ngx.say(err)
            end
        }
    }
--- request
GET /test
--- response_body
busy
--- no_error_log
[error]



=== TEST 27: semaphore wait time default is zero
--- http_config eval: $::HttpConfig
--- config
    location /test {
        content_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local sem = semaphore.new(0)
            local ok, err = sem:wait()
            if not ok then
                ngx.say(err)
            end
        }
    }
--- request
GET /test
--- response_body
busy
--- no_error_log
[error]



=== TEST 28: test semaphore gc
--- http_config eval: $::HttpConfig
--- config
    location /test {
        content_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local sem, err = semaphore.new(0)
            if sem then
                ngx.say("success")
            end
            sem = nil
            collectgarbage("collect")
        }
    }
--- request
GET /test
--- response_body
success
--- log_level: debug
--- error_log
in lua gc, semaphore



=== TEST 29: basic semaphore_mm alloc
--- http_config eval: $::HttpConfig
--- config
    location /test {
        content_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local sem = semaphore.new(0)
            if sem then
                ngx.say("ok")
            end
        }
    }
--- log_level: debug
--- request
GET /test
--- response_body
ok
--- grep_error_log eval: qr/(new block, alloc semaphore|from head of free queue, alloc semaphore)/
--- grep_error_log_out eval
[
"new block, alloc semaphore
",
"from head of free queue, alloc semaphore
",
]



=== TEST 30: basic semaphore_mm free insert tail
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local sems = package.loaded.sems or {}
            package.loaded.sems = sems

            local num_per_block = 4094
            if not sems[num_per_block] then
                for i = 1, num_per_block * 3 do
                    sems[i] = semaphore.new(0)
                end
            end

            for i = 1, 2 do
                if sems[i] then
                    sems[i] = nil
                    ngx.say("ok")
                    break
                end
            end
            collectgarbage("collect")
        }
    }
--- log_level: debug
--- request
GET /t
--- response_body
ok
--- error_log
add to free queue tail



=== TEST 31: basic semaphore_mm free insert head
--- http_config eval: $::HttpConfig
--- config
    location /test {
        content_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local sems = package.loaded.sems or {}
            package.loaded.sems = sems

            local num_per_block = 4094
            if not sems[num_per_block] then
                for i = 1, num_per_block * 3 do
                    sems[i] = semaphore.new(0)
                end
            end

            if sems[#sems] then
                sems[#sems] = nil
                ngx.say("ok")
            end
            collectgarbage("collect")
        }
    }
--- log_level: debug
--- request
GET /test
--- response_body
ok
--- error_log
add to free queue head



=== TEST 32: semaphore_mm free block (load <= 50% & the on the older side)
--- http_config eval: $::HttpConfig
--- config
    location /test {
        content_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local sems = package.loaded.sems or {}
            package.loaded.sems = sems

            local num_per_block = 4094
            if not sems[num_per_block * 3] then
                for i = 1, num_per_block * 3 do
                    sems[i] = semaphore.new(0)
                end

                for i = num_per_block + 1, num_per_block * 2 do
                    sems[i] = nil
                end
            else
                for i = 1, num_per_block do
                    sems[i] = nil
                end
            end

            collectgarbage("collect")
            ngx.say("ok")
        }
    }
--- log_level: debug
--- request
GET /test
--- response_body
ok
--- grep_error_log eval: qr/free semaphore block/
--- grep_error_log_out eval
[
"",
"free semaphore block
",
]



=== TEST 33: basic semaphore count
--- http_config eval: $::HttpConfig
--- config
    location /test {
        content_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local sem = semaphore.new(10)
            local count = sem:count()
            ngx.say(count)

            sem:wait()
            local count = sem:count()
            ngx.say(count)

            sem:post(3)
            local count = sem:count()
            ngx.say(count)
        }
    }
--- request
GET /test
--- response_body
10
9
12
--- no_error_log
[error]
