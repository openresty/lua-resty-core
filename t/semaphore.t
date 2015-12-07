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
$ENV{TEST_NGINX_LUA_PACKAGE_PATH} = "\"$pwd/lib/?.lua;;\"";
#my $lua_default_lib = "/usr/local/openresty/lualib/?.lua";
our $HttpConfig = <<_EOC_;
    lua_package_path "$pwd/lib/?.lua;;";
_EOC_

run_tests();

__DATA__

=== TEST 1: basic semaphore wait post
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
                ngx.exit(200)
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



=== TEST 2: basic semaphore wait post
--- http_config eval: $::HttpConfig
--- config
    location /test {
        content_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local sem = semaphore.new(0)
            local ok, err = sem:wait(0.1)
            ngx.say(tostring(ok).." "..tostring(err))
        }
    }
--- request
GET /test
--- response_body
false timeout
--- no_error_log
[error]



=== TEST 3: basic semaphore wait not allowed in body_filter_by_lua
--- http_config eval: $::HttpConfig
--- config
    location /test {
        body_filter_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local sem = semaphore.new(0)
            local ok, err = sem:wait(1)
            ngx.log(ngx.ERR, err)
        }
        return 200;
    }
--- request
GET /test
--- response_body
--- error_log
API disabled in the context of (unknown)



=== TEST 4: basic semaphore wait not allowed in header_filter_by_lua
--- http_config eval: $::HttpConfig
--- config
    location /test {
        header_filter_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local sem = semaphore.new(0)
            local ok, err = sem:wait(1)
            ngx.log(ngx.ERR, err)
        }
        return 200;
    }
--- request
GET /test
--- response_body
--- error_log
API disabled in the context of header_filter_by_lua*



=== TEST 5: basic semaphore wait not allowed in init_worker_by_lua
--- http_config
    lua_package_path $TEST_NGINX_LUA_PACKAGE_PATH;
    init_worker_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local sem = semaphore.new(0)
            local ok, err = sem:wait(1)
            ngx.log(ngx.ERR, err)
    }
--- config
    location /test {
        echo "ok";
    }
--- request
GET /test
--- response_body
ok
--- grep_error_log eval: qr/API disabled in the context of init_worker_by_lua/
--- grep_error_log_out eval
[
"API disabled in the context of init_worker_by_lua
",
"",
]



=== TEST 6: basic semaphore wait not allowed in set_by_lua
--- http_config eval: $::HttpConfig
--- config
    location /test {
        set_by_lua_block $res {
            local semaphore = require "ngx.semaphore"
            local sem, err = semaphore.new(0)
            local ok, err = sem:wait(1)
            return err
        }
        echo $res;
    }
--- request
GET /test
--- response_body
API disabled in the context of set_by_lua*
--- no_error_log
[error]



=== TEST 7: basic semaphore wait not allowed in log_by_lua
--- http_config eval: $::HttpConfig
--- config
    location /test {
        log_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local sem = semaphore.new(0)
            local ok, err = sem:wait(1)
            ngx.log(ngx.ERR, err)
            return err
        }
        echo "try magics";
    }
--- request
GET /test
--- response_body
try magics
--- error_log
API disabled in the context of log_by_lua*



=== TEST 8: basic semaphore new not allowed in init_by_lua
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
--- grep_error_log eval: qr/no request found/
--- grep_error_log_out eval
[
"no request found
",
"",
]



=== TEST 9: basic semaphore wait post in access_by_lua
--- http_config eval: $::HttpConfig
--- config
    location /test {
        access_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local ret = {}
            local sem = semaphore.new(0)
            local co1 = ngx.thread.spawn(
                            function(sem, ret)
                                ret.wait = sem:wait(10)
                            end,
                            sem, ret)
            local co2 = ngx.thread.spawn(
                function(sem, ret)
                ret.post = sem:post()
                end,
                sem, ret)
            ngx.thread.wait(co1)
            ngx.thread.wait(co2)
            if ret.post and ret.wait then
                ngx.say("right")
            end
            ngx.exit(200)
        }
    }
--- request
GET /test
--- response_body
right
--- no_error_log
[error]



=== TEST 10: basic semaphore wait post in rewrite_by_lua
--- http_config eval: $::HttpConfig
--- config
    location = /test {
        access_log off;
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
        rewrite_by_lua_block {
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
            local ok, err = sem:wait(10)
            if ok then
                ngx.print("wait")
                ngx.exit(200)
            else
                ngx.print("some badthing happen"..err)
                ngx.exit(201)
            end
        }
    }


    location /sem_post {
        rewrite_by_lua_block {
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
             local ok, err = sem:post()
            if ok then
                ngx.print("post")
                ngx.exit(200)
            else
                ngx.print("some badthing happen"..err)
                ngx.exit(201)
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



=== TEST 11: basic semaphore wait in timer.at
--- http_config eval: $::HttpConfig
--- config
    location /test {
       content_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local sem = semaphore.new(0)
            local ok, err = sem:post()
            local function func(premature, g)
                local sem1 = sem
                local ok, err = sem1:wait(10)
                if not ok then
                    ngx.log(ngx.ERR, err)
                end
            end
            ngx.timer.at(0, func, g)
            ngx.sleep(0)
            ngx.say("ok")
       }
    }
--- request
GET /test
--- response_body
ok
--- no_error_log
[error]



=== TEST 12: semaphore post in header_filter_by_lua
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
        header_filter_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local g = package.loaded["semaphore_test"] or {}
            package.loaded["semaphore_test"] = g
            if not g.test then
                local sem, err = semaphore.new(0)
                if not sem then
                    ngx.log(ngx.ERR, err)
                end
                g.test = sem
            end
            local sem = g.test
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



=== TEST 13: test semaphore gc
--- http_config eval: $::HttpConfig
--- config
    location /test {
       content_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local sem, err = semaphore.new(0)
            if sem then
                err = "success"
            end
            sem = nil
            ngx.say(err)
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



=== TEST 14: semaphore post in body_filter_by_lua
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
            local g = package.loaded["semaphore_test"] or {}
            package.loaded["semaphore_test"] = g
            if not g.test then
                local sem, err = semaphore.new(0)
                if not sem then
                    ngx.log(ngx.ERR, err)
                end
                g.test = sem
            end
            local sem = g.test
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



=== TEST 15: semaphore post in log_by_lua
--- http_config eval: $::HttpConfig
--- config
        location /test {
            log_by_lua_block {
                local semaphore = require "ngx.semaphore"
                local sem, err = semaphore.new(0)
                if not sem then
                    ngx.log(ngx.ERR, err)
                end
                local ok, err = sem:post()
                if not ok then
                    ngx.log(ngx.ERR, err)
                else
                    ngx.log(ngx.ERR, "ok")
                end
            }
            content_by_lua_block {
                    ngx.say("post")
                    ngx.exit(200)
            }
        }
--- request
GET /test
--- response_body
post
--- error_log
ok


=== TEST 16: semaphore post in set_by_lua
--- http_config eval: $::HttpConfig
--- config
    location /test{
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
            local g = package.loaded["semaphore_test"] or {}
            package.loaded["semaphore_test"] = g
            if not g.test then
                local sem, err = semaphore.new(0)
                if not sem then
                    ngx.log(ngx.ERR, err)
                end
                g.test = sem
            end
            local sem = g.test
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



=== TEST 17: semaphore post in timer.at
--- http_config eval: $::HttpConfig
--- config
    location /test{
        content_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local g = package.loaded["semaphore_test"] or {}
            package.loaded["semaphore_test"] = g
            g.test = semaphore.new(0)
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
            local g = package.loaded["semaphore_test"] or {}
            package.loaded["semaphore_test"] = g
            local sem = g.test
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
            local g = package.loaded["semaphore_test"] or {}
            package.loaded["semaphore_test"] = g
            local function func(premature)
                local semaphore = require "ngx.semaphore"
                local sem = g.test
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



=== TEST 18: a light thread that to be killed is waiting on a semaphore
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
                sem:wait(10)
            end
            local co = ngx.thread.spawn(func, sem)
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



=== TEST 19: a light thread that is going to exit is waiting on a semaphore
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
                sem:wait(10)
            end
            local co = ngx.thread.spawn(func, sem)
            ngx.say("test")
            ngx.exit(200)
       }
    }
--- log_level: debug
--- request
GET /test
--- response_body
test
--- error_log
http lua semaphore cleanup



=== TEST 20: multi wait and mult post with one semaphore
--- http_config eval: $::HttpConfig
--- config
    location = /test {
        content_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local sem,err = semaphore.new(0)
            if not sem then
                ngx.log(ngx.ERR, err)
                ngx.exit(500)
            end
            local function thread(op, id)
                if op == "wait" then
                    sem:wait(5)
                    ngx.say(op.." "..tostring(id))
                else
                    sem:post()
                end
            end
            local tco = {}

            for i = 1, 3 do
                tco[#tco + 1] = ngx.thread.spawn(thread, "wait", i)
            end

            for i = 1, 3 do
                tco[#tco + 1] = ngx.thread.spawn(thread, "post", i)
            end

            for k,co in pairs(tco) do 
                ngx.thread.wait(co)
            end
        }
    }
--- request
GET /test
--- response_body
wait 1
wait 2
wait 3
--- no_error_log
[error]



=== TEST 21: benchmark
--- http_config eval: $::HttpConfig
--- config
    location = /test {
        access_log off;
        content_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local g = package.loaded["semaphore_test"] or {}
            package.loaded["semaphore_test"] = g
            if g.id == nil then
                g.id = 0
                g.map = {}
            end
            local id = g.id
            g.id = g.id + 1
            local sem = semaphore.new(0)
            g.map[id] = sem
            local res1, res2 = ngx.location.capture_multi{
                { "/sem_wait", { method = ngx.HTTP_POST, body = tostring(id) }},
                { "/sem_post", { method = ngx.HTTP_POST, body = tostring(id)}},
            }
            g.map[id] = nil
            ngx.say("ok")
        }
    }

    location /sem_wait {
        content_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local g = package.loaded["semaphore_test"] or {}
            package.loaded["semaphore_test"] = g
            ngx.req.read_body()
            local body = ngx.req.get_body_data()
            local sem = g.map[tonumber(body)]
            local ok, err = sem:wait(10)
            if ok then
                --ngx.print("wait")
                ngx.exit(200)
            else
                ngx.log(ngx.ERR, err)
                ngx.exit(500)
            end
        }
    }

    location /sem_post {
        content_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local g = package.loaded["semaphore_test"] or {}
            package.loaded["semaphore_test"] = g
            ngx.req.read_body()
            local body = ngx.req.get_body_data()
            local sem = g.map[tonumber(body)]
            local ok, err = sem:post()
            if ok then
                --ngx.print("post")
                ngx.exit(200)
            else
                ngx.log(ngx.ERR, err)
                ngx.exit(500)
            end
        }
    }

--- request
GET /test
--- response_body
ok
--- no_error_log
[error]



=== TEST 22: semaphore wait time is zero
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



=== TEST 23: basic semaphore wait time default is zero
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



=== TEST 23: basic semaphore_mm alloc
--- http_config eval: $::HttpConfig
--- config
    location /test {
       content_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local sem1 = semaphore.new(0)
            --local sem2 = semaphore.new(0)
            ngx.say("ok")
       }
    }
--- log_level: debug
--- request
GET /test
--- response_body
ok
--- grep_error_log eval: qr/(new block, alloc semaphore|free queue, alloc semaphore)/
--- grep_error_log_out eval
[
"new block, alloc semaphore
",
"free queue, alloc semaphore
",
]



=== TEST 23: basic semaphore_mm free insert tail
--- http_config eval: $::HttpConfig
--- config
    location /test {
       content_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local t = {}
            local num_per_block = 4094
            for i=1, num_per_block*2 do 
                t[i] = semaphore.new(0)
            end
            t = nil
            collectgarbage("collect")
            ngx.say("ok")
       }
    }
--- log_level: debug
--- request
GET /test
--- response_body
ok
--- error_log
add to free queue tail



=== TEST 24: basic semaphore_mm free insert head
--- http_config eval: $::HttpConfig
--- config
    location /test {
       content_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local t = {}
            local num_per_block = 4094
            for i=1, num_per_block*2 do 
                t[i] = semaphore.new(0)
            end
            t = nil
            collectgarbage("collect")
            ngx.say("ok")
       }
    }
--- log_level: debug
--- request
GET /test
--- response_body
ok
--- error_log
add to free queue head



=== TEST 25: basic semaphore_mm free block
--- http_config eval: $::HttpConfig
--- config
    location /test {
       content_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local t = {}
            local num_per_block = 4094
            for i=1, num_per_block*2 do 
                t[i] = semaphore.new(0)
            end
            for i=1,num_per_block do 
                t[i] = nil
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
"free semaphore block
",
"",
]


=== TEST 25: basic semaphore count
--- http_config eval: $::HttpConfig
--- config
    location /test {
       content_by_lua_block {
            local semaphore = require "ngx.semaphore"
            local sem = semaphore.new(10)
            local count = sem:count()
            ngx.say(count)
       }
    }
--- log_level: debug
--- request
GET /test
--- response_body
10
--- no_error_log
[error]