# vim:set ft=ts=4 sw=4 et fdm=marker:
use lib 'lib';
use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

#worker_connections(10140);
#workers(1);
#log_level('warn');
master_process_enabled(1);
repeat_each(1);

plan tests => repeat_each() * (blocks() * 3);

my $pwd = cwd();

no_long_string();
#no_diff();
$ENV{TEST_NGINX_LUA_PACKAGE_PATH} = "\"$pwd/lib/?.lua;;\"";
our $HttpConfig = <<_EOC_;
    lua_shared_dict shdict 4m;
    lua_package_path "$pwd/lib/?.lua;;";

    init_by_lua_block {
        require "resty.core"
        local process = require "ngx.process"
        local ok, err = process.enable_privileged_agent()
        if not ok then
            ngx.log(ngx.ERR, "failed to enable_privileged_agent: ", err)
        end
    }

    init_worker_by_lua_block {
        local function test(pre)
            if pre then
                return
            end

            local semaphore = require "ngx.semaphore"
            local sem = semaphore.new()

            ngx.log(ngx.ERR, "created semaphore object")

            local function sem_wait()

                local ok, err = sem:wait(100)
                if not ok then
                    ngx.log(ngx.ERR, "err: ", err)
                else
                    ngx.log(ngx.ERR, "wait success")
                end
            end

            while not ngx.worker.exiting() do
                local co = ngx.thread.spawn(sem_wait)
                ngx.thread.wait(co)
            end
        end

        local ok, err = ngx.timer.at(0, test)
        if not ok then
            ngx.log(ngx.ERR, "failed to create semaphore timer err: ", err)
        end

        local function reload(pre)
            if pre then
                return
            end

            shdict = ngx.shared.shdict
            local success = shdict:add("reloaded", 1)
            if not success then
                return
            end

            ngx.log(ngx.ERR, "try to reload nginx")

            local f, err = io.open(ngx.config.prefix() .. "/logs/nginx.pid", "r")
            if not f then
                ngx.say("failed to open nginx.pid: ", err)
                return
            end

            local pid = f:read()

            f:close()
            os.execute("kill -HUP " .. pid)
        end

        local typ = require "ngx.process".type
        if typ() == "privileged agent" then
            local ok, err = ngx.timer.at(0.1, reload)
            if not ok then
                ngx.log(ngx.ERR, "failed to create semaphore timer err: ", err)
            end
        end
    }

_EOC_

run_tests();

__DATA__

=== TEST 1: timer + reload
--- http_config eval: $::HttpConfig
--- config
    location /test {
        content_by_lua_block {
            ngx.sleep(1)
            ngx.say("hello")
        }
    }
--- request
GET /test
--- response_body
hello
--- log_level: warn
--- grep_error_log eval: qr/created semaphore object|try to reload nginx|semaphore gc wait queue is not empty/
--- grep_error_log_out
created semaphore object
created semaphore object
try to reload nginx
created semaphore object
created semaphore object
--- skip_nginx: 3: < 1.11.2