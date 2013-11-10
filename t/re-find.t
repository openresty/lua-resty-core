# vim:set ft= ts=4 sw=4 et fdm=marker:
use lib 'lib';
use Test::Nginx::Socket;
use Cwd qw(cwd);

#worker_connections(1014);
#master_process_enabled(1);
#log_level('warn');

repeat_each(2);

plan tests => repeat_each() * (blocks() * 5 - 1);

my $pwd = cwd();

our $HttpConfig = <<_EOC_;
    lua_package_path "$pwd/lib/?.lua;;";
    init_by_lua '
        -- local verbose = true
        local verbose = false
        local outfile = "$Test::Nginx::Util::ErrLogFile"
        -- local outfile = "/tmp/v.log"
        if verbose then
            local dump = require "jit.dump"
            dump.on(nil, outfile)
        else
            local v = require "jit.v"
            v.on(outfile)
        end

        require "resty.core"
        -- jit.opt.start("hotloop=1")
        -- jit.opt.start("loopunroll=1000000")
        -- jit.off()
    ';
_EOC_

#no_diff();
no_long_string();
run_tests();

__DATA__

=== TEST 1: matched, no submatch, no jit compile, no regex cache
--- http_config eval: $::HttpConfig
--- config
    location = /re {
        access_log off;
        content_by_lua '
            local from, to, err
            local find = ngx.re.find
            local s = "a"
            for i = 1, 100 do
                from, to, err = find(s, "a")
            end
            if err then
                ngx.log(ngx.ERR, "failed: ", err)
                return
            end
            if not from then
                ngx.log(ngx.ERR, "no match")
                return
            end
            ngx.say("from: ", from)
            ngx.say("to: ", to)
            ngx.say("matched: ", string.sub(s, from, to))
        ';
    }
--- request
GET /re
--- response_body
from: 1
to: 1
matched: a
--- error_log eval
qr/\[TRACE   \d+ "content_by_lua":5 loop\]/
--- no_error_log
[error]
bad argument type



=== TEST 2: matched, no submatch, jit compile, regex cache
--- http_config eval: $::HttpConfig
--- config
    location = /re {
        access_log off;
        content_by_lua '
            local from, to, err
            local find = ngx.re.find
            local s = "a"
            for i = 1, 200 do
                from, to, err = find(s, "a", "jo")
            end
            if err then
                ngx.log(ngx.ERR, "failed: ", err)
                return
            end
            if not from then
                ngx.log(ngx.ERR, "no match")
                return
            end
            ngx.say("from: ", from)
            ngx.say("to: ", to)
            ngx.say("matched: ", string.sub(s, from, to))
        ';
    }
--- request
GET /re
--- response_body
from: 1
to: 1
matched: a
--- error_log eval
qr/\[TRACE   \d+ "content_by_lua":5 loop\]/
--- no_error_log
[error]
NYI



=== TEST 3: not matched, no submatch, jit compile, regex cache
--- http_config eval: $::HttpConfig
--- config
    location = /re {
        access_log off;
        content_by_lua '
            local from, to, err
            local find = ngx.re.find
            local s = "b"
            for i = 1, 200 do
                from, to, err = find(s, "a", "jo")
            end
            if err then
                ngx.log(ngx.ERR, "failed: ", err)
                return
            end
            if not from then
                ngx.say("no match")
                return
            end
            ngx.say("from: ", from)
            ngx.say("to: ", to)
            ngx.say("matched: ", string.sub(s, from, to))
        ';
    }
--- request
GET /re
--- response_body
no match
--- error_log eval
qr/\[TRACE   \d+ "content_by_lua":5 loop\]/
--- no_error_log
[error]

