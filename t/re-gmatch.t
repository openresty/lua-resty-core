# vim:set ft= ts=4 sw=4 et fdm=marker:
use lib 'lib';
use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

#worker_connections(1014);
#master_process_enabled(1);
#log_level('warn');

repeat_each(2);

plan tests => repeat_each() * (blocks() * 4 - 2);

my $pwd = cwd();

our $HttpConfig = <<_EOC_;
    lua_package_path "$pwd/lib/?.lua;../lua-resty-lrucache/lib/?.lua;;";
    init_by_lua_block {
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
    }
_EOC_

#no_diff();
no_long_string();
check_accum_error_log();
run_tests();

__DATA__

=== TEST 1: matched, no submatch, no jit compile, no regex cache
--- http_config eval: $::HttpConfig
--- config
    location = /re {
        content_by_lua_block {
            local m1, m2
            local gmatch = ngx.re.gmatch
            for _ = 1, 100 do
                local iter = gmatch("hello, world", [[\w+]])
                m1 = iter()
                m2 = iter()
            end
            ngx.say("matched: ", m1[0])
            ngx.say("matched: ", m2[0])
        }
    }
--- request
GET /re
--- response_body
matched: hello
matched: world
--- error_log eval
qr/\[TRACE   \d+ content_by_lua\(nginx\.conf:\d+\):4 loop\]/
--- no_error_log
[error]



=== TEST 2: matched, no submatch, jit compile, regex cache
--- http_config eval: $::HttpConfig
--- config
    location = /re {
        content_by_lua_block {
            local m1, m2
            local gmatch = ngx.re.gmatch
            for _ = 1, 100 do
                local iter = gmatch("hello, world", [[\w+]])
                m1 = iter()
                m2 = iter()
            end
            ngx.say("matched: ", m1[0])
            ngx.say("matched: ", m2[0])
        }
    }
--- request
GET /re
--- response_body
matched: hello
matched: world
--- error_log eval
qr/\[TRACE   \d+ content_by_lua\(nginx\.conf:\d+\):4 loop\]/
--- no_error_log
[error]



=== TEST 3: not matched, no submatch, jit compile, regex cache
--- http_config eval: $::HttpConfig
--- config
    location = /re {
        content_by_lua_block {
            local m, err
            local gmatch = ngx.re.gmatch
            for _ = 1, 100 do
                local iter = gmatch("hello, world", "[abc]+", "jo")
                m, err = iter()
                if err then
                    ngx.log(ngx.ERR, "failed: ", err)
                    return
                end
            end
            if not m then
                ngx.say("no match")
                return
            end
        }
    }
--- request
GET /re
--- response_body
no match
--- error_log eval
qr/\[TRACE   \d+ content_by_lua\(nginx\.conf:\d+\):4 loop\]/
--- no_error_log
[error]



=== TEST 4: not matched, no submatch, no jit compile, no regex cache
--- http_config eval: $::HttpConfig
--- config
    location = /re {
        content_by_lua_block {
            local m, err
            local gmatch = ngx.re.gmatch
            for _ = 1, 100 do
                local iter = gmatch("hello, world", "[abc]+")
                m, err = iter()
                if err then
                    ngx.log(ngx.ERR, "failed: ", err)
                    return
                end
            end
            if not m then
                ngx.say("no match")
                return
            end
        }
    }
--- request
GET /re
--- response_body
no match
--- error_log eval
qr/\[TRACE   \d+ content_by_lua\(nginx\.conf:\d+\):4 loop\]/
--- no_error_log
[error]



=== TEST 5: submatches, matched, no regex cache
--- http_config eval: $::HttpConfig
--- config
    location = /re {
        content_by_lua_block {
            local m1, m2
            local gmatch = ngx.re.gmatch
            for _ = 1, 100 do
                local iter = gmatch("hello, world", [[(\w)(\w+)]])
                m1 = iter()
                m2 = iter()
            end
            ngx.say("matched: ", m1[0])
            ngx.say("$1: ", m1[1])
            ngx.say("$2: ", m1[2])
            ngx.say("$3: ", m1[3])
            ngx.say("matched: ", m2[0])
            ngx.say("$1: ", m2[1])
            ngx.say("$2: ", m2[2])
            ngx.say("$3: ", m2[3])
        }
    }
--- request
GET /re
--- response_body
matched: hello
$1: h
$2: ello
$3: nil
matched: world
$1: w
$2: orld
$3: nil
--- no_error_log
[error]



=== TEST 6: submatches, matched, with regex cache
--- http_config eval: $::HttpConfig
--- config
    location = /re {
        content_by_lua_block {
            local m1, m2
            local gmatch = ngx.re.gmatch
            for _ = 1, 100 do
                local iter = gmatch("hello, world", [[(\w)(\w+)]], "jo")
                m1 = iter()
                m2 = iter()
            end
            ngx.say("matched: ", m1[0])
            ngx.say("$1: ", m1[1])
            ngx.say("$2: ", m1[2])
            ngx.say("$3: ", m1[3])
            ngx.say("matched: ", m2[0])
            ngx.say("$1: ", m2[1])
            ngx.say("$2: ", m2[2])
            ngx.say("$3: ", m2[3])
        }
    }
--- request
GET /re
--- response_body
matched: hello
$1: h
$2: ello
$3: nil
matched: world
$1: w
$2: orld
$3: nil
--- error_log eval
qr/\[TRACE\s+\d+\s+/
--- no_error_log
[error]



=== TEST 7: named submatches
--- http_config eval: $::HttpConfig
--- config
    location = /re {
        content_by_lua_block {
            local m1, m2
            local gmatch = ngx.re.gmatch
            for _ = 1, 100 do
                local iter = gmatch("hello,world", [[(?<first>\w)(\w+)]], "jo")
                m1 = iter()
                m2 = iter()
            end
            ngx.say("matched: ", m1[0])
            ngx.say("$1: ", m1[1])
            ngx.say("$2: ", m1[2])
            ngx.say("$first: ", m1.first)
            ngx.say("$second: ", m1.second)
            ngx.say("matched: ", m2[0])
            ngx.say("$1: ", m2[1])
            ngx.say("$2: ", m2[2])
            ngx.say("$first: ", m2.first)
            ngx.say("$second: ", m2.second)
        }
    }
--- request
GET /re
--- response_body
matched: hello
$1: h
$2: ello
$first: h
$second: nil
matched: world
$1: w
$2: orld
$first: w
$second: nil
--- error_log eval
qr/\[TRACE\s+\d+\s+/
--- no_error_log
[error]



=== TEST 8: unmatched captures are false
--- http_config eval: $::HttpConfig
--- config
    location = /re {
        content_by_lua_block {
            local iter = ngx.re.gmatch(
                "hello! world!", [[(\w+)(, .+)?(!)]], "jo")
            if iter then
                while true do
                    local m = iter()
                    if not m then
                        return
                    end
                    ngx.say(m[0])
                    ngx.say(m[1])
                    ngx.say(m[2])
                    ngx.say(m[3])
                end
            end
        }
    }
--- request
GET /re
--- response_body
hello!
hello
false
!
world!
world
false
!
--- error_log eval
qr/\[TRACE\s+\d+\s+/
--- no_error_log
[error]



=== TEST 9: unmatched trailing captures are false
--- http_config eval: $::HttpConfig
--- config
    location = /re {
        content_by_lua_block {
            local iter = ngx.re.gmatch("hello", [[(\w+)(, .+)?(!)?]], "jo")
            if iter then
                while true do
                    local m = iter()
                    if not m then
                        return
                    end
                    ngx.say(m[0])
                    ngx.say(m[1])
                    ngx.say(m[2])
                    ngx.say(m[3])
                end
            end
        }
    }
--- request
GET /re
--- response_body
hello
hello
false
false
--- error_log eval
qr/\[TRACE\s+\d+\s+/
--- no_error_log
[error]



=== TEST 10: unmatched name captures are false
--- http_config eval: $::HttpConfig
--- config
    location = /re {
        content_by_lua_block {
            local iter = ngx.re.gmatch(
                "hello! world!",
                [[(?<first>\w+)(?<second>, .+)?(?<third>!)]], "jo")
            if iter then
                while true do
                    local m = iter()
                    if not m then
                        return
                    end
                    ngx.say(m[0])
                    ngx.say(m[1])
                    ngx.say(m[2])
                    ngx.say(m[3])
                    ngx.say(m.first)
                    ngx.say(m.second)
                    ngx.say(m.third)
                end
            end
        }
    }
--- request
GET /re
--- response_body
hello!
hello
false
!
hello
false
!
world!
world
false
!
world
false
!
--- error_log eval
qr/\[TRACE\s+\d+\s+/
--- no_error_log
[error]



=== TEST 11: subject is not a string type
--- http_config eval: $::HttpConfig
--- config
    location /re {
        content_by_lua_block {
            local iter = ngx.re.gmatch(120345, "[1-9]+", "jo")
            local m1 = iter()
            local m2 = iter()
            ngx.say(m1[0])
            ngx.say(m2[0])
        }
    }
--- request
GET /re
--- response_body
12
345
--- no_error_log
[error]
attempt to get length of local 'subj' (a number value)



=== TEST 12: an exhausted gmatch iterator should return nil
--- http_config eval: $::HttpConfig
--- config
    location = /re {
        content_by_lua_block {
            local iter = ngx.re.gmatch("hello", [[\w+]])
            local m = iter()
            ngx.say("matched: ", m[0])
            ngx.say("matched: ", iter())
            ngx.say("matched: ", iter())
        }
    }
--- request
GET /re
--- response_body
matched: hello
matched: nil
matched: nil
--- no_error_log
[error]
