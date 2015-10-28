# vim:set ft= ts=4 sw=4 et fdm=marker:
use lib 'lib';
use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

#worker_connections(10140);
master_process_enabled(1);
workers(1);
#log_level('warn');

repeat_each(2);

plan tests => repeat_each() * (blocks() * 3);

my $pwd = cwd();

no_long_string();
#no_diff();

#my $lua_default_lib = "/usr/local/openresty/lualib/?.lua";
our $HttpConfig = <<_EOC_;
    lua_package_path "$pwd/lib/?.lua;;";
    init_by_lua '
            require "resty.core"
    ';
_EOC_

our $HttpConfigInitByLua= <<_EOC_;
    lua_package_path "$pwd/lib/?.lua;;";
    init_by_lua '
            require "resty.core"

            local g = _G
            local semaphore = require "ngx.semaphore"
            local sem, err = semaphore.new(0)
            g.err = err
    ';
_EOC_

our $HttpConfigIntWorkerBy = <<_EOC_;
    lua_package_path "$pwd/lib/?.lua;;";
    init_worker_by_lua '
            require "resty.core"

            local semaphore = require "ngx.semaphore"
            local sem = semaphore.new(0)
            local ok, err = sem:wait(1)
            local g = _G
            g.test = err
    ';

_EOC_

run_tests();

__DATA__

=== TEST 1: basic semaphore wait post
--- http_config eval: $::HttpConfig
--- config
    location = /test {
        access_log off;
        content_by_lua '
        local res1, res2 = ngx.location.capture_multi{
          { "/sem_wait"},
          { "/sem_post"},
        }
        ngx.say(res1.status)
        ngx.say(res1.body)
        ngx.say(res2.status)
        ngx.say(res2.body)
        ';
    }
    location /sem_wait {
        content_by_lua '
            local semaphore = require "ngx.semaphore"
            local g = getmetatable(_G).__index

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
        ';
    }

    location /sem_post {
        content_by_lua '
            local semaphore = require "ngx.semaphore"
            local g = getmetatable(_G).__index
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
                ngx.exit(500)
            end

    ';
    }
--- no_check_leak
--- request
GET /test
--- response_body
200
wait
200
post
--- no_error_log
[error]



=== TEST 2: basic semaphore wait post
--- http_config eval: $::HttpConfig
--- config
    location /test {
        content_by_lua '
            local semaphore = require "ngx.semaphore"
            local sem = semaphore.new(0)
            local ok, err = sem:wait(0.1)
            ngx.say(tostring(ok).." "..tostring(err))
        ';
    }
--- no_check_leak
--- request
GET /test
--- response_body
false timeout
--- no_error_log
[error]



=== TEST 3: basic semaphore wait not allow in body_filter_by_lua
--- http_config eval: $::HttpConfig
--- config
    location /test {
        body_filter_by_lua '
            local semaphore = require "ngx.semaphore"
            local sem = semaphore.new(0)
            local ok, err = sem:wait(1)
            ngx.log(ngx.ERR, err)
        ';
        return 200;
    }
--- no_check_leak
--- request
GET /test
--- response_body
--- error_log
API disabled in the context of (unknown)



=== TEST 4: basic semaphore wait not allow in header_filter_by_lua
--- http_config eval: $::HttpConfig
--- config
    location /test {
        header_filter_by_lua '
            local semaphore = require "ngx.semaphore"
            local sem = semaphore.new(0)
            local ok, err = sem:wait(1)
            ngx.log(ngx.ERR, err)
        ';
        return 200;
    }
--- no_check_leak
--- request
GET /test
--- response_body
--- error_log
API disabled in the context of header_filter_by_lua*



=== TEST 5: basic semaphore wait not allow in init_worker_by_lua
--- http_config eval: $::HttpConfigIntWorkerBy
--- config
    location /test {
       content_by_lua '
            local semaphore = require "ngx.semaphore"
            local g = getmetatable(_G).__index
            ngx.say(g.test)
       ';
    }
--- no_check_leak
--- request
GET /test
--- response_body
API disabled in the context of init_worker_by_lua*
--- no_error_log
[error]



=== TEST 6: basic semaphore wait not allow in set_by_lua
--- http_config eval: $::HttpConfig
--- config
    location /test {
        set_by_lua $res '
            local semaphore = require "ngx.semaphore"
            local sem, err = semaphore.new(0)
            local ok, err = sem:wait(1)
            return err
        ';
        echo $res;
    }
--- no_check_leak
--- request
GET /test
--- response_body
API disabled in the context of set_by_lua*
--- no_error_log
[error]



=== TEST 7: basic semaphore wait not allow in log_by_lua
--- http_config eval: $::HttpConfig
--- config
    location /test {
        log_by_lua '
            local semaphore = require "ngx.semaphore"
            local sem = semaphore.new(0)
            local ok, err = sem:wait(1)
            ngx.log(ngx.ERR, err)
            return err
        ';
        echo "try magics";
    }
--- no_check_leak
--- request
GET /test
--- response_body
try magics
--- error_log
API disabled in the context of log_by_lua*



=== TEST 8: basic semaphore new not allow in init_by_lua
--- http_config eval: $::HttpConfigInitByLua
--- config
    location /test {
        content_by_lua '
            local g = getmetatable(_G).__index
            ngx.say(g.err)
        ';
    }
--- no_check_leak
--- request
GET /test
--- response_body
ngx_http_lua_ffi_semaphore_new ngx_alloc failed
--- no_error_log
[error]



=== TEST 9: basic semaphore wait post in access_by_lua
--- http_config eval: $::HttpConfig
--- config
     location /test {
        access_by_lua '
            local semaphore = require "ngx.semaphore"
            local g = getmetatable(_G).__index
            if not g.test then
                local sem, err = semaphore.new(0)
                if not sem then
                    ngx.say(err)
                    ngx.exit(500)
                end
                g.test = sem
            end
            local sem = g.test
            local ret = {}
            local co1 = ngx.thread.spawn(
                            function(sem,ret)
                                ret.wait = sem:wait(10)
                            end,
                                sem,ret)
            local co2 = ngx.thread.spawn(
                function(sem,ret)
                ret.post = sem:post()
                end,
                sem,ret)
            ngx.thread.wait(co1)
            ngx.thread.wait(co2)
            if ret.post and ret.wait then
                ngx.say("right")
            end
            ngx.exit(200)
        ';
    }
--- no_check_leak
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
        content_by_lua '
        local res1, res2 = ngx.location.capture_multi{
          { "/sem_wait"},
          { "/sem_post"},
        }
        ngx.say(res1.status)
        ngx.say(res1.body)
        ngx.say(res2.status)
        ngx.say(res2.body)
        ';
    }

    location /sem_wait {
        rewrite_by_lua '
            local semaphore = require "ngx.semaphore"
            local g = getmetatable(_G).__index
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
        ';
    }

    location /sem_post {
        rewrite_by_lua '
            local semaphore = require "ngx.semaphore"
            local g = getmetatable(_G).__index
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
    ';
    }
--- no_check_leak
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
       content_by_lua '
            local semaphore = require "ngx.semaphore"
            local sem = semaphore.new(0)
            local g = getmetatable(_G).__index
            local ok, err = sem:post()
            g.test = sem
            local function func(premature, g)
                local sem1 = g.test
                local ok, err = sem1:wait(10)
                if not ok then
                    ngx.log(ngx.ERR, err)
                end
            end
            ngx.timer.at(0,func,g)
            ngx.sleep(2)
            ngx.say("ok")
            --ngx.log(ngx.ERR,semaphore.err)
       ';
    }
--- no_check_leak
--- request
GET /test
--- response_body
ok
--- no_error_log
[error]



=== TEST 12: semaphore post in header_filter_by_lua
--- http_config eval: $::HttpConfig
--- config
    location /test{
        content_by_lua '
            local res1,res2 = ngx.location.capture_multi{
                {"/sem_wait"},
                {"/sem_post"},
            }
            ngx.say(res1.status)
            ngx.say(res1.body)
            ngx.say(res2.status)
            ngx.say(res2.body)
        ';
    }

    location /sem_wait {
        content_by_lua '
            local semaphore = require "ngx.semaphore"
            local g = getmetatable(_G).__index
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
        ';
    }

    location /sem_post {
        header_filter_by_lua '
            local semaphore = require "ngx.semaphore"
            local g = getmetatable(_G).__index
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
    ';
    content_by_lua '
            ngx.print("post")
            ngx.exit(200)
    ';
    }
--- no_check_leak
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
       content_by_lua '
            local semaphore = require "ngx.semaphore"
            local sem, err = semaphore.new(0)
            local g = getmetatable(_G).__index
            if not sem then
                g.err = err
            else
                g.err = "success"
            end
            sem = nil
            local semaphore = require "ngx.semaphore"
            ngx.say(g.err)
            collectgarbage("collect")
       ';
    }
--- request
GET /test
--- response_body
success
--- log_level: debug
--- error_log
ngx_http_lua_ffi_semaphore_gc



=== TEST 14: semaphore post in body_filter_by_lua
--- http_config eval: $::HttpConfig
--- config
    location /test{
        content_by_lua '
            local res1,res2 = ngx.location.capture_multi{
                {"/sem_wait"},
                {"/sem_post"},
            }
            ngx.say(res1.status)
            ngx.say(res1.body)
            ngx.say(res2.status)
            ngx.say(res2.body)
        ';
    }

    location /sem_wait {
        content_by_lua '
            local semaphore = require "ngx.semaphore"
            local g = getmetatable(_G).__index
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
        ';
    }

    location /sem_post {
        body_filter_by_lua '
            local semaphore = require "ngx.semaphore"
            local g = getmetatable(_G).__index
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
    ';
    content_by_lua '
            ngx.print("post")
            ngx.exit(200)
    ';
    }
--- no_check_leak
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
        log_by_lua '
            local semaphore = require "ngx.semaphore"
            local g = getmetatable(_G).__index
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
    ';
    content_by_lua '
            ngx.say("post")
            ngx.exit(200)
    ';
    }
--- no_check_leak
--- request
GET /test
--- response_body
post
--- no_error_log
[error]



=== TEST 16: semaphore post in set_by_lua
--- http_config eval: $::HttpConfig
--- config
    location /test{
        content_by_lua '
            local res1,res2 = ngx.location.capture_multi{
                {"/sem_wait"},
                {"/sem_post"},
            }
            ngx.say(res1.status)
            ngx.say(res1.body)
            ngx.say(res2.status)
            ngx.say(res2.body)
        ';
    }

    location /sem_wait {
        content_by_lua '
            local semaphore = require "ngx.semaphore"
            local g = getmetatable(_G).__index
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
        ';
    }

    location /sem_post {
        set_by_lua $res '
            local semaphore = require "ngx.semaphore"
            local g = getmetatable(_G).__index
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
    ';
    content_by_lua '
            ngx.print("post")
            ngx.exit(200)
    ';
    }
--- no_check_leak
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
        content_by_lua '
            local res1,res2 = ngx.location.capture_multi{
                {"/sem_wait"},
                {"/sem_post"},
            }
            ngx.say(res1.status)
            ngx.say(res1.body)
            ngx.say(res2.status)
            ngx.say(res2.body)
        ';
    }

    location /sem_wait {
        content_by_lua '
            local semaphore = require "ngx.semaphore"
            local g = getmetatable(_G).__index
            if not g.test then
                local sem, err = semaphore.new(0)
                if not sem then
                    ngx.say(err)
                    ngx.exit(500)
                end
                g.test = sem
            end
            local sem = g.test
            local ok, err = sem:wait(2)
            if ok then
                ngx.print("wait")
                ngx.exit(200)
            else
                ngx.exit(500)
            end
        ';
    }

    location /sem_post {
    content_by_lua '
            local g = getmetatable(_G).__index
            local function func(premature, g)
                local semaphore = require "ngx.semaphore"
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
            end
            ngx.timer.at(0, func,g)
            ngx.sleep(2)
            ngx.print("post")
            ngx.exit(200)
    ';
    }
--- no_check_leak
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



=== TEST 18: a light thread that to be killed is waitting a semaphore
--- http_config eval: $::HttpConfig
--- config
    location /test {
       content_by_lua '
            local semaphore = require "ngx.semaphore"
            local sem = semaphore.new(0)
            if not sem then
                error("create failed")
            end
            local function func(sem)
                sem:wait(10)
            end
            local co = ngx.thread.spawn(func,sem)
            ngx.thread.kill(co)
            ngx.say("test")
       ';
    }
--- log_level: debug
--- no_check_leak
--- request
GET /test
--- response_body
test
--- error_log
ngx_http_lua_semaphore_cleanup



=== TEST 19: a light thread that is going to exit is waitting a semaphore
--- http_config eval: $::HttpConfig
--- config
    location /test {
       content_by_lua '
            local semaphore = require "ngx.semaphore"
            local sem = semaphore.new(0)
            if not sem then
                error("create failed")
            end
            local function func(sem)
                sem:wait(10)
            end
            local co = ngx.thread.spawn(func,sem)
            ngx.say("test")
            ngx.exit(200)
       ';
    }
--- log_level: debug
--- no_check_leak
--- request
GET /test
--- response_body
test
--- error_log
ngx_http_lua_semaphore_cleanup



=== TEST 20: test thread wait or post a sem in one request
--- http_config eval: $::HttpConfig
--- config
    location = /test {
        access_log off;
        content_by_lua '
            local semaphore = require "ngx.semaphore"

            local g = getmetatable(_G).__index
            local sem, err = semaphore.new(0)
            if not sem then
                ngx.say(err)
                ngx.exit(500)
            end
            g.test = sem

            local sem2, err = semaphore.new(0)
            if not sem2 then
                ngx.say(err)
                ngx.exit(500)
            end
            g.test_next = sem2

            g.log = {}
            g.log_i = 0
            g.wait_id = 0
            g.wakeup_id = 0
            --0:wait 1:post 2:post_all
            g.test_op = {0,1,1,0}
            local function func(op,index,g)
                local res
                if op == 0 then
                    local sem = g.test
                    local sem2 = g.test_next
                    sem2:post()
                    g.wait_id = g.wait_id +1
                    local wait_id = g.wait_id
                    local ok, err = sem:wait(10)
                    g.wakeup_id = g.wakeup_id + 1
                    g.log_i = g.log_i + 1
                    local wake_id = g.wakeup_id
                    g.log[g.log_i] = {state=ok, err=err,op=0,wait_id = wait_id,wake_id = wake_id}
                else
                    local sem = g.test
                    local sem2 = g.test_next
                    sem2:post()
                    local ok, err = sem:post()
                    g.log_i = g.log_i + 1
                    g.log[g.log_i] = {state=ok, err=err,op=1}
                end
            end
            local co_array = {}
            for i=1,#g.test_op do
                co_array[i] = ngx.thread.spawn(func,g.test_op[i],i,g)
                sem2:wait(10)
            end
            for i=1,#co_array do
                ngx.thread.wait(co_array[i])
            end
            for i=1,g.log_i do
                --ngx.say(g.log[i].op)
                if g.log[i].op == 0 then
                    ngx.say("wait")
                elseif g.log[i].op == 1 then
                    ngx.say("post")
                else
                    ngx.say("post_all")
                end

                if g.log[i].state then
                    ngx.say(g.log[i].state)
                    if g.log[i].op == 0 then
                        ngx.say(g.log[i].wait_id)
                        ngx.say(g.log[i].wake_id)
                    end
                else
                    ngx.say(g.log[i].err)
                end
            end
        ';
    }
--- no_check_leak
--- request
GET /test
--- response_body
post
true
post
true
wait
true
1
1
wait
true
2
2
--- no_error_log
[error]



=== TEST 21: benchmark
--- http_config eval: $::HttpConfig
--- config
    location = /test {
        access_log off;
        content_by_lua '
            local semaphore = require "ngx.semaphore"
            local g = getmetatable(_G).__index
            if g.id == nil then
                g.id = 0
                g.map = {}
            end
            local id = g.id
            g.id = g.id + 1
            local sem = semaphore.new(0)
            g.map[id] = sem
            local res1, res2 = ngx.location.capture_multi{
                { "/sem_wait",{ method = ngx.HTTP_POST, body = tostring(id) }},
                { "/sem_post",{ method = ngx.HTTP_POST,body = tostring(id)}},
            }
            g.map[id] = nil
            ngx.say("ok")
        ';
    }

    location /sem_wait {
        content_by_lua '
            local semaphore = require "ngx.semaphore"
            local g = getmetatable(_G).__index
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
        ';
    }

    location /sem_post {
        content_by_lua '
            local semaphore = require "ngx.semaphore"
            local g = getmetatable(_G).__index
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

    ';
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
       content_by_lua '
            local semaphore = require "ngx.semaphore"
            local sem = semaphore.new(0)
            local ok, err = sem:wait(0)
            if not ok then
                ngx.say(err)
            end
       ';
}
--- no_check_leak
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
       content_by_lua '
            local semaphore = require "ngx.semaphore"
            local sem = semaphore.new(0)
            local ok, err = sem:wait()
            if not ok then
                ngx.say(err)
            end
       ';
}
--- no_check_leak
--- request
GET /test
--- response_body
busy
--- no_error_log
[error]

