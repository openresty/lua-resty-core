# vim:set ft= ts=4 sw=4 et fdm=marker:
use lib '.';
use t::TestCore;

repeat_each(2);

plan tests => repeat_each() * (blocks() * 3 + 8);

add_block_preprocessor(sub {
    my $block = shift;

    my $http_config = $block->http_config || '';
    my $init_by_lua_block = $block->init_by_lua_block || '';

    $http_config .= <<_EOC_;
    lua_package_path '$t::TestCore::lua_package_path';
    init_by_lua_block {
        $t::TestCore::init_by_lua_block
        $init_by_lua_block
    }
_EOC_

    $block->set_value("http_config", $http_config);

    if (!defined $block->error_log) {
        $block->set_value("no_error_log", "[error]");
    }

    if (!defined $block->request) {
        $block->set_value("request", "GET /t");
    }
});

env_to_nginx("PATH");
no_long_string();
run_tests();

__DATA__

=== TEST 1: write process
--- config
    location = /t {
        content_by_lua_block {
            local ngx_pipe = require "ngx.pipe"
            local proc = ngx_pipe.spawn({'tee'})

            local function write(...)
                local bytes, err = proc:write(...)
                if not bytes then
                    ngx.say(err)
                    return
                end
                ngx.say(bytes)
            end

            write('')
            write('hello')
            write(' world')

            local data, err = proc:stdout_read_any(1024)
            if not data then
                ngx.say(err)
            else
                ngx.say(data)
            end
        }
    }
--- response_body
0
5
6
hello world



=== TEST 2: write process, bad pipe
--- config
    location = /t {
        content_by_lua_block {
            local ngx_pipe = require "ngx.pipe"
            local proc = ngx_pipe.spawn({'echo', 'a'})

            ngx.sleep(0.1)
            local bytes, err = proc:write("test")
            if not bytes then
                ngx.say(err)
                return
            end
            ngx.say(bytes)
        }
    }
--- response_body
closed
--- error_log eval
qr/lua pipe write data error pipe:[0-9A-F]+ \(\d+: Broken pipe\)/



=== TEST 3: write process after waiting
--- config
    location = /t {
        content_by_lua_block {
            local ngx_pipe = require "ngx.pipe"
            local proc = ngx_pipe.spawn({"echo", "hello world"})

            local ok, err = proc:wait()
            if not ok then
                ngx.say("wait failed: ", err)
                return
            end

            local data, err = proc:write("a")
            if not data then
                ngx.say(err)
            else
                ngx.say(data)
            end
        }
    }
--- response_body
closed



=== TEST 4: write process, timeout
--- config
    location = /t {
        content_by_lua_block {
            local ngx_pipe = require "ngx.pipe"
            local proc, err = ngx_pipe.spawn({"sleep", 1})
            if not proc then
                ngx.say(err)
                return
            end

            local data = ("1234"):rep(2048)
            proc:set_timeouts(100)
            local total = 0
            local step = #data

            while true do
                local data, err = proc:write(data)
                if not data then
                    ngx.say(err)
                    break
                end

                total = total + step
                if total > 64 * step then
                    break
                end
            end

            ngx.log(ngx.WARN, "total write before timeout:", total)
        }
    }
--- response_body
timeout
--- no_error_log
[error]
--- error_log
lua pipe add timer for writing: 100(ms)
lua pipe write yielding



=== TEST 5: write process, yield and write again
--- config
    location = /t {
        content_by_lua_block {
            local ngx_pipe = require "ngx.pipe"
            local proc, err = ngx_pipe.spawn({"tee"})
            if not proc then
                ngx.say(err)
                return
            end

            local data = ("1234"):rep(2048)
            proc:set_timeouts(100)
            local total = 0
            local step = #data

            while true do
                local data, err = proc:write(data)
                if not data then
                    ngx.say(err)
                    break
                end

                total = total + step
                if total > 64 * step then
                    break
                end
            end
            ngx.log(ngx.WARN, "total write before timeout:", total)

            local function drain()
                local data, err = proc:stdout_read_bytes(#data / 2)
                if not data then
                    ngx.log(ngx.ERR, "drain failed: ", err)
                end
            end

            ngx.thread.spawn(function()
                drain()
                ngx.sleep(0.1)
                drain()
            end)

            proc:set_timeouts(400)
            local bytes, err = proc:write(data)
            if not bytes then
                ngx.say(err)
            else
                ngx.say(bytes)
            end
        }
    }
--- response_body
timeout
8192
--- no_error_log
[error]
--- error_log
lua pipe write yielding



=== TEST 6: more than one coroutines write
--- config
    location = /t {
        content_by_lua_block {
            local ngx_pipe = require "ngx.pipe"
            local proc, err = ngx_pipe.spawn({"sleep", 1})
            if not proc then
                ngx.say(err)
                return
            end

            local data = ("1234"):rep(2048)
            proc:set_timeouts(100)
            local total = 0
            local step = #data

            -- make writers blocked later
            while true do
                local data, err = proc:write(data)
                if not data then
                    ngx.say(err)
                    break
                end

                total = total + step
                if total > 64 * step then
                    break
                end
            end

            local function write()
                local data, err = proc:write(data)
                if not data then
                    ngx.say(err)
                else
                    ngx.say(data)
                end
            end

            local th1 = ngx.thread.spawn(write)
            local th2 = ngx.thread.spawn(write)
            ngx.thread.wait(th1)
            ngx.thread.wait(th2)
            ngx.thread.spawn(write)
        }
    }
--- response_body
timeout
pipe busy writing
timeout
timeout
--- no_error_log
[error]
--- error_log
lua pipe add timer for writing: 100(ms)
lua pipe write yielding



=== TEST 7: write process, aborted by uthread kill
--- config
    location = /t {
        content_by_lua_block {
            local ngx_pipe = require "ngx.pipe"
            local proc, err = ngx_pipe.spawn({"sleep", 1})
            if not proc then
                ngx.say(err)
                return
            end

            local data = ("1234"):rep(2048)
            proc:set_timeouts(100)
            local total = 0
            local step = #data

            -- make writers blocked later
            while true do
                local data, err = proc:write(data)
                if not data then
                    ngx.say(err)
                    break
                end

                total = total + step
                if total > 64 * step then
                    break
                end
            end

            local function write()
                proc:write(data)
                ngx.log(ngx.ERR, "can't reach here")
            end

            local th = ngx.thread.spawn(write)
            ngx.thread.kill(th)

            local data, err = proc:write(data)
            if not data then
                ngx.say(err)
            else
                ngx.say(data)
            end
        }
    }
--- response_body
timeout
timeout
--- no_error_log
[error]
--- error_log
lua pipe add timer for writing: 100(ms)
lua pipe write yielding
lua pipe proc write cleanup



=== TEST 8: write and read process
--- config
    location = /t {
        content_by_lua_block {
            local ngx_pipe = require "ngx.pipe"
            package.loaded.proc = ngx_pipe.spawn({'tee'})
            local res1, res2 = ngx.location.capture_multi{{"/req1"}, {"/req2"}}
            ngx.print(res1.body)
            ngx.print(res2.body)
        }
    }

    location = /req1 {
        content_by_lua_block {
            local proc = package.loaded.proc
            local data, err = proc:stdout_read_any(1024)
            if not data then
                ngx.say(err)
            end

            data, err = proc:write(data)
            if not data then
                ngx.say(err)
            end
        }
    }

    location = /req2 {
        content_by_lua_block {
            local proc = package.loaded.proc
            local data, err = proc:write("payload")
            if not data then
                ngx.say(err)
            end

            ngx.sleep(0.2) -- yield to let other req read and write the data
            data, err = proc:stdout_read_any(1024)
            if not data then
                ngx.say(err)
            else
                ngx.say(data)
            end
        }
    }
--- response_body
payload



=== TEST 9: write process, support table, number and boolean arguments
--- config
    location = /t {
        content_by_lua_block {
            local ngx_pipe = require "ngx.pipe"
            local proc = ngx_pipe.spawn({'tee'})

            local function write(...)
                local bytes, err = proc:write(...)
                if not bytes then
                    ngx.say(err)
                    return
                end
                ngx.say(bytes)
            end

            write(10)
            write({"hello", " ", "world"})

            local data, err = proc:stdout_read_any(1024)
            if not data then
                ngx.say(err)
            else
                ngx.say(data)
            end
        }
    }
--- response_body
2
11
10hello world



=== TEST 10: write process, throw error if bad argument is written
--- config
    location = /t {
        content_by_lua_block {
            local ngx_pipe = require "ngx.pipe"
            local proc = ngx_pipe.spawn({'tee'})

            local function write(...)
                local ok, err = pcall(proc.write, proc, ...)
                if not ok then
                    ngx.say(err)
                    return
                end
            end

            write(true)
            write(nil)
            write(ngx.null)
        }
    }
--- response_body
bad data arg: string, number, or table expected, got boolean
bad data arg: string, number, or table expected, got nil
bad data arg: string, number, or table expected, got userdata
