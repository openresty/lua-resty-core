# vim:set ft= ts=4 sw=4 et fdm=marker:
use Test::Nginx::Socket::Lua;
use Cwd qw(abs_path realpath cwd);
use File::Basename;

repeat_each(2);

plan tests => repeat_each() * (blocks() * 3 + 2);

my $pwd = cwd();

add_block_preprocessor(sub {
    my $block = shift;

    my $http_config = $block->http_config || '';
    my $init_by_lua_block = $block->init_by_lua_block || 'require "resty.core"';

    $http_config .= <<_EOC_;

    lua_package_path "$pwd/lib/?.lua;../lua-resty-lrucache/lib/?.lua;;";
    init_by_lua_block {
        $init_by_lua_block
    }
_EOC_

    $block->set_value("http_config", $http_config);

    if (!defined $block->error_log) {
        $block->set_value("no_error_log", "[error]\n[alert]\n[emerg]");
    }

    if (!defined $block->request) {
        $block->set_value("request", "GET /t");
    }
});

env_to_nginx("PATH");
master_on();
no_long_string();
run_tests();

__DATA__

=== TEST 1: reset the cpu affinity in the sub-process
--- main_config
worker_cpu_affinity 0001;
--- config
    location = /t {
        content_by_lua_block {
            local ngx_pipe = require "ngx.pipe"
            local nproc, err = ngx_pipe.spawn({"nproc"})
            if not nproc then
                ngx.say(err)
                return
            end

            local ncpu, err = nproc:stdout_read_line()
            if not ncpu then
                ngx.say(err)
                return
            end

            if tonumber(ncpu) < 2 then
                -- when ncpu is 1, this test is a smoking test.
                -- We could not ensure the affinity is reset, but we could
                -- ensure no error occurs.
                ngx.say("ok")
                return
            end

            local proc, err = ngx_pipe.spawn({"sleep", 3600})
            if not proc then
                ngx.say(err)
                return
            end

            -- ensure affinity is already reset before running taskset
            ngx.sleep(0.1)

            local taskset, err = ngx_pipe.spawn({"taskset", "-pc", proc:pid()})
            if not taskset then
                ngx.say(err)
                return
            end

            local report, err = taskset:stdout_read_line()
            if not report then
                ngx.say(err)
                return
            end

            ngx.say(report)
        }
    }
--- response_body_like
(ok|pid \d+'s current affinity list: 0[-,]\d+)
