# vim:set ft= ts=4 sw=4 et fdm=marker:
use lib 'lib';
use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

#worker_connections(10140);
master_process_enabled(1);
workers(1);
log_level('warn');

repeat_each(2);

plan tests => repeat_each() * (blocks() * 3);

my $pwd = cwd();

no_long_string();
#no_diff();

my $lua_default_lib = "/usr/local/openresty/lualib/?.lua";
our $HttpConfig = <<_EOC_;
    lua_package_path "$pwd/lib/?.lua;$lua_default_lib;";
_EOC_

our $HttpConfigInitByLua= <<_EOC_;
    lua_package_path "$pwd/lib/?.lua;$lua_default_lib;";
    init_by_lua '
            require "resty.core.semaphore"
            local sem  = ngx.semaphore.new(0)
            local ok,err=sem:wait(1)
            ngx.semaphore.err = err
    ';
_EOC_

our $HttpConfigIntWorkerBy = <<_EOC_;
    lua_package_path "$pwd/lib/?.lua;$lua_default_lib;";
    init_worker_by_lua '
            require "resty.core.semaphore"
            local sem  = ngx.semaphore.new(0)
            local ok,err=sem:wait(1)
            ngx.semaphore.test = err
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
          { "/sub_sem_wait"},
          { "/sub_sem_post"},
        }
        ngx.say(res1.status)
        ngx.say(res1.body)
        ngx.say(res2.status)
        ngx.say(res2.body)
        ';
    }
     location /sub_sem_wait {
        proxy_pass $scheme://127.0.0.1:$server_port/sem_wait;
    }

    location /sub_sem_post {
        proxy_pass $scheme://127.0.0.1:$server_port/sem_post;
    }

    location /sem_wait {
        content_by_lua '
            require "resty.core.semaphore"
            if not ngx.semaphore.test then
                local sem,err = ngx.semaphore.new(0)
                if not sem then
                    ngx.say(err)
                    ngx.exit(500)
                end
                ngx.semaphore.test = sem
            end
            local sem  = ngx.semaphore.test
            local ok,err = sem:wait(10)
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
            require "resty.core.semaphore"
            if not ngx.semaphore.test then
                local sem,err = ngx.semaphore.new(0)
                if not sem then
                    ngx.say(err)
                    ngx.exit(500)
                end
                ngx.semaphore.test = sem
            end
            local sem  = ngx.semaphore.test
            local ok,err = sem:post()
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
            require "resty.core.semaphore"
            local sem  = ngx.semaphore.new(0)
            local ok,err=sem:wait(1)
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
            require "resty.core.semaphore"
            local sem = ngx.semaphore.new(0)
            local ok,err=sem:wait(1)
            ngx.log(ngx.ERR,err)
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
            require "resty.core.semaphore"
            local sem  = ngx.semaphore.new(0)
            local ok,err=sem:wait(1)
            ngx.log(ngx.ERR,err)
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
            require "resty.core.semaphore"
            ngx.say(ngx.semaphore.test)
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
            require "resty.core.semaphore"
            local sem,err = ngx.semaphore.new(0)
            local ok,err=sem:wait(1)
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
            require "resty.core.semaphore"
            local sem  = ngx.semaphore.new(0)
            local ok,err=sem:wait(1)
            ngx.log(ngx.ERR,err)
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



=== TEST 8: basic semaphore wait not allow in init_by_lua
--- http_config eval: $::HttpConfigInitByLua
--- config
    location /test {
        content_by_lua '
            ngx.say(ngx.semaphore.err)
        ';
    }
--- no_check_leak
--- request
GET /test
--- response_body
request is null
--- no_error_log
[error]



=== TEST 9: basic semaphore wait post in access_by_lua
--- http_config eval: $::HttpConfig
--- config
    location = /test {
        access_log off;
        content_by_lua '
        local res1, res2 = ngx.location.capture_multi{
          { "/sub_sem_wait"},
          { "/sub_sem_post"},
        }
        ngx.say(res1.status)
        ngx.say(res1.body)
        ngx.say(res2.status)
        ngx.say(res2.body)
        ';
    }
     location /sub_sem_wait {
        proxy_pass $scheme://127.0.0.1:$server_port/sem_wait;
    }

    location /sub_sem_post {
        proxy_pass $scheme://127.0.0.1:$server_port/sem_post;
    }

    location /sem_wait {
        access_by_lua '
            require "resty.core.semaphore"
            if not ngx.semaphore.test then
                local sem,err = ngx.semaphore.new(0)
                if not sem then
                    ngx.say(err)
                    ngx.exit(500)
                end
                ngx.semaphore.test = sem
            end
            local sem  = ngx.semaphore.test
            local ok,err = sem:wait(1)
            if ok then
                ngx.print("wait")
                ngx.exit(200)
            else
                ngx.print(err)
                ngx.exit(200)
            end
        ';
    }

    location /sem_post {
        access_by_lua '
            require "resty.core.semaphore"
            if not ngx.semaphore.test then
                local sem,err = ngx.semaphore.new(0)
                if not sem then
                    ngx.say(err)
                    ngx.exit(500)
                end
                ngx.semaphore.test = sem
            end
            local sem  = ngx.semaphore.test
            local ok,err = sem:post()
            if ok then
                ngx.print("post")
                ngx.exit(200)
            else
                ngx.print(err)
                ngx.exit(200)
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



=== TEST 10: basic semaphore wait post in rewrite_by_lua
--- http_config eval: $::HttpConfig
--- config
    location = /test {
        access_log off;
        content_by_lua '
        local res1, res2 = ngx.location.capture_multi{
          { "/sub_sem_wait"},
          { "/sub_sem_post"},
        }
        ngx.say(res1.status)
        ngx.say(res1.body)
        ngx.say(res2.status)
        ngx.say(res2.body)
        ';
    }
     location /sub_sem_wait {
        proxy_pass $scheme://127.0.0.1:$server_port/sem_wait;
    }

    location /sub_sem_post {
        proxy_pass $scheme://127.0.0.1:$server_port/sem_post;
    }

    location /sem_wait {
        rewrite_by_lua '
            require "resty.core.semaphore"
            if not ngx.semaphore.test then
                local sem,err = ngx.semaphore.new(0)
                if not sem then
                    ngx.say(err)
                    ngx.exit(500)
                end
                ngx.semaphore.test = sem
            end
            local sem  = ngx.semaphore.test
            local ok,err = sem:wait(10)
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
            require "resty.core.semaphore"
            if not ngx.semaphore.test then
                local sem,err = ngx.semaphore.new(0)
                if not sem then
                    ngx.say(err)
                    ngx.exit(500)
                end
                ngx.semaphore.test = sem
            end
            local sem  = ngx.semaphore.test
             local ok,err = sem:post()
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
            require "resty.core.semaphore"
            local sem  = ngx.semaphore.new(0)
            local ok,err = sem:post()
            ngx.semaphore.test = sem
            local function func(premature)
                local sem1 = ngx.semaphore.test
                local ok,err = sem1:wait(10)
                if not ok then
                    ngx.log(ngx.ERR,err)
                end
            end
            ngx.timer.at(0,func,sem,sem2)
            ngx.sleep(2)
            ngx.say("ok")
            --ngx.log(ngx.ERR,ngx.semaphore.err)
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
                {"/sub_sem_wait"},
                {"/sub_sem_post"},
            }
            ngx.say(res1.status)
            ngx.say(res1.body)
            ngx.say(res2.status)
            ngx.say(res2.body)
        ';
    }
     location /sub_sem_wait {
        proxy_pass $scheme://127.0.0.1:$server_port/sem_wait;
    }

    location /sub_sem_post {
        proxy_pass $scheme://127.0.0.1:$server_port/sem_post;
    }

    location /sem_wait {
        content_by_lua '
            require "resty.core.semaphore"
            if not ngx.semaphore.test then
                local sem,err = ngx.semaphore.new(0)
                if not sem then
                    ngx.say(err)
                    ngx.exit(500)
                end
                ngx.semaphore.test = sem
            end
            local sem  = ngx.semaphore.test
            local ok,err = sem:wait(10)
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
            require "resty.core.semaphore"
            if not ngx.semaphore.test then
                local sem,err = ngx.semaphore.new(0)
                if not sem then
                    ngx.log(ngx.ERR,err)
                end
                ngx.semaphore.test = sem
            end
            local sem  = ngx.semaphore.test
            local ok,err = sem:post()
            if not ok then
                ngx.log(ngx.ERR,err)
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
            require "resty.core.semaphore"
            local sem,err = ngx.semaphore.new(0)
            if not sem then
                ngx.semaphore.err = err
            else
                ngx.semaphore.err = "success"
            end
            sem = nil
            require "resty.core.semaphore"
            ngx.say(ngx.semaphore.err)
            collectgarbage("collect")
       ';
    }
--- request
GET /test
--- response_body
success
--- log_level: debug
--- error_log
ngx_http_lua_ffi_sem_gc

=== TEST 14: semaphore post in body_filter_by_lua
--- http_config eval: $::HttpConfig
--- config
    location /test{
        content_by_lua '
            local res1,res2 = ngx.location.capture_multi{
                {"/sub_sem_wait"},
                {"/sub_sem_post"},
            }
            ngx.say(res1.status)
            ngx.say(res1.body)
            ngx.say(res2.status)
            ngx.say(res2.body)
        ';
    }
     location /sub_sem_wait {
        proxy_pass $scheme://127.0.0.1:$server_port/sem_wait;
    }

    location /sub_sem_post {
        proxy_pass $scheme://127.0.0.1:$server_port/sem_post;
    }

    location /sem_wait {
        content_by_lua '
            require "resty.core.semaphore"
            if not ngx.semaphore.test then
                local sem,err = ngx.semaphore.new(0)
                if not sem then
                    ngx.say(err)
                    ngx.exit(500)
                end
                ngx.semaphore.test = sem
            end
            local sem  = ngx.semaphore.test
            local ok,err = sem:wait(10)
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
            require "resty.core.semaphore"
            if not ngx.semaphore.test then
                local sem,err = ngx.semaphore.new(0)
                if not sem then
                    ngx.log(ngx.ERR,err)
                end
                ngx.semaphore.test = sem
            end
            local sem  = ngx.semaphore.test
            local ok,err = sem:post()
            if not ok then
                ngx.log(ngx.ERR,err)
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
    location /test{
        content_by_lua '
            local res1,res2 = ngx.location.capture_multi{
                {"/sub_sem_wait"},
                {"/sub_sem_post"},
            }
            ngx.say(res1.status)
            ngx.say(res1.body)
            ngx.say(res2.status)
            ngx.say(res2.body)
        ';
    }
     location /sub_sem_wait {
        proxy_pass $scheme://127.0.0.1:$server_port/sem_wait;
    }

    location /sub_sem_post {
        proxy_pass $scheme://127.0.0.1:$server_port/sem_post;
    }

    location /sem_wait {
        content_by_lua '
            require "resty.core.semaphore"
            if not ngx.semaphore.test then
                local sem,err = ngx.semaphore.new(0)
                if not sem then
                    ngx.say(err)
                    ngx.exit(500)
                end
                ngx.semaphore.test = sem
            end
            local sem  = ngx.semaphore.test
            local ok,err = sem:wait(10)
            if ok then
                ngx.print("wait")
                ngx.exit(200)
            else
                ngx.exit(500)
            end
        ';
    }

    location /sem_post {
        log_by_lua '
            require "resty.core.semaphore"
            if not ngx.semaphore.test then
                local sem,err = ngx.semaphore.new(0)
                if not sem then
                    ngx.log(ngx.ERR,err)
                end
                ngx.semaphore.test = sem
            end
            local sem  = ngx.semaphore.test
            local ok,err = sem:post()
            if not ok then
                ngx.log(ngx.ERR,err)
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



=== TEST 16: semaphore post in set_by_lua
--- http_config eval: $::HttpConfig
--- config
    location /test{
        content_by_lua '
            local res1,res2 = ngx.location.capture_multi{
                {"/sub_sem_wait"},
                {"/sub_sem_post"},
            }
            ngx.say(res1.status)
            ngx.say(res1.body)
            ngx.say(res2.status)
            ngx.say(res2.body)
        ';
    }
     location /sub_sem_wait {
        proxy_pass $scheme://127.0.0.1:$server_port/sem_wait;
    }

    location /sub_sem_post {
        proxy_pass $scheme://127.0.0.1:$server_port/sem_post;
    }

    location /sem_wait {
        content_by_lua '
            require "resty.core.semaphore"
            if not ngx.semaphore.test then
                local sem,err = ngx.semaphore.new(0)
                if not sem then
                    ngx.say(err)
                    ngx.exit(500)
                end
                ngx.semaphore.test = sem
            end
            local sem  = ngx.semaphore.test
            local ok,err = sem:wait(10)
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
            require "resty.core.semaphore"
            if not ngx.semaphore.test then
                local sem,err = ngx.semaphore.new(0)
                if not sem then
                    ngx.log(ngx.ERR,err)
                end
                ngx.semaphore.test = sem
            end
            local sem  = ngx.semaphore.test
            local ok,err = sem:post()
            if not ok then
                ngx.log(ngx.ERR,err)
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
                {"/sub_sem_wait"},
                {"/sub_sem_post"},
            }
            ngx.say(res1.status)
            ngx.say(res1.body)
            ngx.say(res2.status)
            ngx.say(res2.body)
        ';
    }
     location /sub_sem_wait {
        proxy_pass $scheme://127.0.0.1:$server_port/sem_wait;
    }

    location /sub_sem_post {
        proxy_pass $scheme://127.0.0.1:$server_port/sem_post;
    }

    location /sem_wait {
        content_by_lua '
            require "resty.core.semaphore"
            if not ngx.semaphore.test then
                local sem,err = ngx.semaphore.new(0)
                if not sem then
                    ngx.say(err)
                    ngx.exit(500)
                end
                ngx.semaphore.test = sem
            end
            local sem  = ngx.semaphore.test
            local ok,err = sem:wait(10)
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
            local function func()
                require "resty.core.semaphore"
                if not ngx.semaphore.test then
                    local sem,err = ngx.semaphore.new(0)
                    if not sem then
                        ngx.log(ngx.ERR,err)
                    end
                    ngx.semaphore.test = sem
                end
                local sem  = ngx.semaphore.test
                local ok,err = sem:post()
                if not ok then
                    ngx.log(ngx.ERR,err)
                end
            end
            ngx.timer.at(0,func)
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



=== TEST 18: repeat operation on one semaphore by wait,post
--- http_config eval: $::HttpConfig
--- config
    location = /test {
        access_log off;
        content_by_lua '
            require "resty.core.semaphore"

            local sem,err = ngx.semaphore.new(0)
            if not sem then
                ngx.say(err)
                ngx.exit(500)
            end
            ngx.semaphore.test = sem

            local sem2,err = ngx.semaphore.new(0)
            if not sem2 then
                ngx.say(err)
                ngx.exit(500)
            end
            ngx.semaphore.test_next = sem2

            ngx.semaphore.log = {}
            ngx.semaphore.log_i = 0

            --0:wait 1:post 2:post_all
            ngx.semaphore.test_op = {0,1,1,0,1,0}
            local function func(op,index)
                local res
                if op == 0 then
                    res = ngx.location.capture("/sub_sem_wait")
                else
                    res = ngx.location.capture("/sub_sem_post")
                end
            end
            local co_array = {}
            for i=1,#ngx.semaphore.test_op do
                co_array[i] = ngx.thread.spawn(func,ngx.semaphore.test_op[i],i)
                sem2:wait(10)
            end
            for i=1,#co_array do
                ngx.thread.wait(co_array[i])
            end
            for i=1,ngx.semaphore.log_i do
                --ngx.say(ngx.semaphore.log[i].op)
                if ngx.semaphore.log[i].op == 0 then
                    ngx.say("wait")
                else
                    ngx.say("post")
                end

                if ngx.semaphore.log[i].state then
                    ngx.say(ngx.semaphore.log[i].state)
                else
                    ngx.say(ngx.semaphore.log[i].err)
                end
            end
        ';
    }
     location /sub_sem_wait {
        proxy_pass $scheme://127.0.0.1:$server_port/sem_wait;
    }

    location /sub_sem_post {
        proxy_pass $scheme://127.0.0.1:$server_port/sem_post;
    }

    location /sem_wait {
        content_by_lua '
            local sem  = ngx.semaphore.test
            local sem2 = ngx.semaphore.test_next
            sem2:post()
            local ok,err = sem:wait(10)
            ngx.semaphore.log_i = ngx.semaphore.log_i + 1
            ngx.semaphore.log[ngx.semaphore.log_i] = {state=ok,err=err,op=0}
        ';
    }

    location /sem_post {
        content_by_lua '
            local sem  = ngx.semaphore.test
            local sem2 = ngx.semaphore.test_next
            sem2:post()
             local ok,err = sem:post()
            ngx.semaphore.log_i = ngx.semaphore.log_i + 1
            ngx.semaphore.log[ngx.semaphore.log_i] = {state=ok,err=err,op=1}

    ';
    }

--- no_check_leak
--- request
GET /test
--- response_body
post
true
wait
true
post
true
wait
true
post
true
wait
true
--- no_error_log
[error]



=== TEST 19: a light thread that to be killed is waitting a semaphore
--- http_config eval: $::HttpConfig
--- config
    location /test {
       content_by_lua '
            require "resty.core.semaphore"
            local sem = ngx.semaphore.new(0)
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
ngx_http_lua_semphore_cleanup



=== TEST 20: a light thread that is going to exit is waitting a semaphore
--- http_config eval: $::HttpConfig
--- config
    location /test {
       content_by_lua '
            require "resty.core.semaphore"
            local sem = ngx.semaphore.new(0)
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
ngx_http_lua_semphore_cleanup



=== TEST 21: if light thread wake up as a queue
--- http_config eval: $::HttpConfig
--- config
    location = /test {
        access_log off;
        content_by_lua '
            require "resty.core.semaphore"

            local sem,err = ngx.semaphore.new(0)
            if not sem then
                ngx.say(err)
                ngx.exit(500)
            end
            ngx.semaphore.test = sem

            local sem2,err = ngx.semaphore.new(0)
            if not sem2 then
                ngx.say(err)
                ngx.exit(500)
            end
            ngx.semaphore.test_next = sem2

            ngx.semaphore.log = {}
            ngx.semaphore.log_i = 0
            ngx.semaphore.wait_id = 0
            ngx.semaphore.wakeup_id = 0
            --0:wait 1:post 2:post_all
            ngx.semaphore.test_op = {0,1,1,0}
            local function func(op,index)
                local res
                if op == 0 then
                    res = ngx.location.capture("/sub_sem_wait")
                else
                    res = ngx.location.capture("/sub_sem_post")
                end
            end
            local co_array = {}
            for i=1,#ngx.semaphore.test_op do
                co_array[i] = ngx.thread.spawn(func,ngx.semaphore.test_op[i],i)
                sem2:wait(10)
            end
            for i=1,#co_array do
                ngx.thread.wait(co_array[i])
            end
            for i=1,ngx.semaphore.log_i do
                --ngx.say(ngx.semaphore.log[i].op)
                if ngx.semaphore.log[i].op == 0 then
                    ngx.say("wait")
                else
                    ngx.say("post")
                end

                if ngx.semaphore.log[i].state then
                    ngx.say(ngx.semaphore.log[i].state)
                    if ngx.semaphore.log[i].op == 0 then
                        ngx.say(ngx.semaphore.log[i].wait_id)
                        ngx.say(ngx.semaphore.log[i].wake_id)
                    end
                else
                    ngx.say(ngx.semaphore.log[i].err)
                end
            end
        ';
    }
     location /sub_sem_wait {
        proxy_pass $scheme://127.0.0.1:$server_port/sem_wait;
    }

    location /sub_sem_post {
        proxy_pass $scheme://127.0.0.1:$server_port/sem_post;
    }


    location /sem_wait {
        content_by_lua '
            local sem  = ngx.semaphore.test
            local sem2 = ngx.semaphore.test_next
            sem2:post()
            ngx.semaphore.wait_id = ngx.semaphore.wait_id +1
            local wait_id = ngx.semaphore.wait_id
            local ok,err = sem:wait(10)
            ngx.semaphore.wakeup_id = ngx.semaphore.wakeup_id + 1
            ngx.semaphore.log_i = ngx.semaphore.log_i + 1
            local wake_id = ngx.semaphore.wakeup_id
            ngx.semaphore.log[ngx.semaphore.log_i] = {state=ok,err=err,op=0,wait_id = wait_id,wake_id = wake_id}
        ';
    }

    location /sem_post {
        content_by_lua '
            local sem  = ngx.semaphore.test
            local sem2 = ngx.semaphore.test_next
            sem2:post()
             local ok,err = sem:post()
            ngx.semaphore.log_i = ngx.semaphore.log_i + 1
            ngx.semaphore.log[ngx.semaphore.log_i] = {state=ok,err=err,op=1}

    ';
    }
--- no_check_leak
--- request
GET /test
--- response_body
post
true
wait
true
1
1
post
true
wait
true
2
2
--- no_error_log
[error]



=== TEST 22: test thread wait or post a sem in one request
--- http_config eval: $::HttpConfig
--- config
    location = /test {
        access_log off;
        content_by_lua '
            require "resty.core.semaphore"

            local sem,err = ngx.semaphore.new(0)
            if not sem then
                ngx.say(err)
                ngx.exit(500)
            end
            ngx.semaphore.test = sem

            local sem2,err = ngx.semaphore.new(0)
            if not sem2 then
                ngx.say(err)
                ngx.exit(500)
            end
            ngx.semaphore.test_next = sem2

            ngx.semaphore.log = {}
            ngx.semaphore.log_i = 0
            ngx.semaphore.wait_id = 0
            ngx.semaphore.wakeup_id = 0
            --0:wait 1:post 2:post_all
            ngx.semaphore.test_op = {0,1,1,0}
            local function func(op,index)
                local res
                if op == 0 then
                    local sem  = ngx.semaphore.test
                    local sem2 = ngx.semaphore.test_next
                    sem2:post()
                    ngx.semaphore.wait_id = ngx.semaphore.wait_id +1
                    local wait_id = ngx.semaphore.wait_id
                    local ok,err = sem:wait(10)
                    ngx.semaphore.wakeup_id = ngx.semaphore.wakeup_id + 1
                    ngx.semaphore.log_i = ngx.semaphore.log_i + 1
                    local wake_id = ngx.semaphore.wakeup_id
                    ngx.semaphore.log[ngx.semaphore.log_i] = {state=ok,err=err,op=0,wait_id = wait_id,wake_id = wake_id}
                else
                    local sem  = ngx.semaphore.test
                    local sem2 = ngx.semaphore.test_next
                    sem2:post()
                    local ok,err = sem:post()
                    ngx.semaphore.log_i = ngx.semaphore.log_i + 1
                    ngx.semaphore.log[ngx.semaphore.log_i] = {state=ok,err=err,op=1}
                end
            end
            local co_array = {}
            for i=1,#ngx.semaphore.test_op do
                co_array[i] = ngx.thread.spawn(func,ngx.semaphore.test_op[i],i)
                sem2:wait(10)
            end
            for i=1,#co_array do
                ngx.thread.wait(co_array[i])
            end
            for i=1,ngx.semaphore.log_i do
                --ngx.say(ngx.semaphore.log[i].op)
                if ngx.semaphore.log[i].op == 0 then
                    ngx.say("wait")
                elseif ngx.semaphore.log[i].op == 1 then
                    ngx.say("post")
                else
                    ngx.say("post_all")
                end

                if ngx.semaphore.log[i].state then
                    ngx.say(ngx.semaphore.log[i].state)
                    if ngx.semaphore.log[i].op == 0 then
                        ngx.say(ngx.semaphore.log[i].wait_id)
                        ngx.say(ngx.semaphore.log[i].wake_id)
                    end
                else
                    ngx.say(ngx.semaphore.log[i].err)
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



=== TEST 23: test semaphore in websocket
--- http_config eval: $::HttpConfig
--- config
    location = /c {
        content_by_lua '
            local function push_data(data)
             res = ngx.location.capture(
                 "/push_data",
                 { method = ngx.HTTP_POST, body = data }
             )
            end
            local client = require "resty.websocket.client"
            local wb, err = client:new()
            local uri = "ws://127.0.0.1:" .. ngx.var.server_port .. "/s"
            -- ngx.say("uri: ", uri)
            local ok, err = wb:connect(uri)
            if not ok then
                ngx.say("failed to connect: " .. err)
                return
            end
            local function thread_recv(wb)
                while true do
                    local data, typ, err = wb:recv_frame()
                    if not data then
                        ngx.say("failed to receive 1st frame: ", err)
                        return
                    end
                    --ngx.say(data,typ,err)
                    if typ == "close" then
                        break
                    else
                        ngx.say(data)
                    end
                end
            end
            local co_recv = ngx.thread.spawn(thread_recv,wb)
            local cos_push = {}
            for i=1,4 do
                cos_push[i] = ngx.thread.spawn(push_data,tostring("data:"..i))
            end
            cos_push[#cos_push+1] = ngx.thread.spawn(push_data,tostring("close"))
            ngx.thread.wait(co_recv)
            for i=1,#cos_push do
                ngx.thread.wait(cos_push[i])
            end
        ';
    }
    location = /push_data {
        content_by_lua '
            ngx.req.read_body()
            local body = ngx.req.get_body_data()
            require "resty.core.semaphore"
            if ngx.semaphore.test == nil then
                ngx.semaphore.test = ngx.semaphore.new(0)
            end
            if ngx.semaphore.arr == nil then
                ngx.semaphore.arr = {}
                ngx.semaphore.arr_wi = 1
                ngx.semaphore.arr_ri = 1
            end
            ngx.semaphore.arr[ngx.semaphore.arr_wi] = body
            ngx.semaphore.arr_wi = ngx.semaphore.arr_wi + 1
            ngx.semaphore.test:post()
        ';
    }
    location = /s {
        content_by_lua '
            local server = require "resty.websocket.server"
            local wb, err = server:new()
            if not wb then
                ngx.log(ngx.ERR, "failed to new websocket: ", err)
                return ngx.exit(444)
            end

            require "resty.core.semaphore"
            if ngx.semaphore.test == nil then
                ngx.semaphore.test = ngx.semaphore.new(0)
            end
            local sem = ngx.semaphore.test
            while true do
                local ok,err = sem:wait(10)
                if not ok then
                    ngx.log(ngx.ERR,err)
                end
                local data = ngx.semaphore.arr[ngx.semaphore.arr_ri]
                ngx.semaphore.arr_ri = ngx.semaphore.arr_ri + 1
                if data == "close" then
                    wb:send_close(1,"close")
                    break
                else
                    local bytes, err = wb:send_text(data)
                    if not bytes then
                        ngx.log(ngx.ERR, "failed to send the 2nd text: ", err)
                        return ngx.exit(444)
                    end
                end
            end
        ';
    }
--- no_check_leak
--- request
GET /c
--- response_body
data:1
data:2
data:3
data:4
--- no_error_log
[error]



=== TEST 24: benchmark
--- http_config eval: $::HttpConfig
--- config
    location = /test {
        access_log off;
        content_by_lua '
            require "resty.core.semaphore"
            if ngx.semaphore.id == nil then
                ngx.semaphore.id = 0
                ngx.semaphore.map = {}
            end
            local id = ngx.semaphore.id
            ngx.semaphore.id = ngx.semaphore.id + 1
            local sem = ngx.semaphore.new(0)
            ngx.semaphore.map[id] = sem
            local res1, res2 = ngx.location.capture_multi{
                { "/sem_wait",{ method = ngx.HTTP_POST, body = tostring(id) }},
                { "/sem_post",{ method = ngx.HTTP_POST,body = tostring(id)}},
            }
            ngx.semaphore.map[id] = nil
            ngx.say("ok")
        ';
    }

     location /sub_sem_wait {
        proxy_pass $scheme://127.0.0.1:$server_port/sem_wait;
    }

    location /sub_sem_post {
        proxy_pass $scheme://127.0.0.1:$server_port/sem_post;
    }

    location /sem_wait {
        content_by_lua '
            require "resty.core.semaphore"
            ngx.req.read_body()
            local body = ngx.req.get_body_data()
            local sem  = ngx.semaphore.map[tonumber(body)]
            local ok,err = sem:wait(10)
            if ok then
                --ngx.print("wait")
                ngx.exit(200)
            else
                ngx.log(ngx.ERR,err)
                ngx.exit(500)
            end
        ';
    }

    location /sem_post {
        content_by_lua '
            require "resty.core.semaphore"
            ngx.req.read_body()
            local body = ngx.req.get_body_data()
            local sem  = ngx.semaphore.map[tonumber(body)]
            local ok,err = sem:post()
            if ok then
                --ngx.print("post")
                ngx.exit(200)
            else
                ngx.log(ngx.ERR,err)
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



=== TEST 25: semaphore wait time is zero
--- http_config eval: $::HttpConfig
--- config
    location /test {
       content_by_lua '
            require "resty.core.semaphore"
            local sem = ngx.semaphore.new(0)
            local ok,err = sem:wait(0)
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



=== TEST 26: basic semaphore wait time default is zero
--- http_config eval: $::HttpConfig
--- config
    location /test {
       content_by_lua '
            require "resty.core.semaphore"
            local sem = ngx.semaphore.new(0)
            local ok,err = sem:wait()
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



=== TEST 27: basic semaphore wait time default is less than zero
--- http_config eval: $::HttpConfig
--- config
    location /test {
       content_by_lua '
            require "resty.core.semaphore"
            local sem = ngx.semaphore.new(-1)
            local ok,err = sem:wait(-1)
            if not ok then
                ngx.say(err)
            end
       ';
}
--- no_check_leak
--- request
GET /test
--- response_body
time must not less than 0
--- no_error_log
[error]

