# vim:set ft= ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

#worker_connections(1014);
#master_process_enabled(1);
log_level('error');

repeat_each(2);

plan tests => repeat_each() * (blocks() * 3 - 5);

my $pwd = cwd();

add_block_preprocessor(sub {
    my $block = shift;

    my $http_config = $block->http_config || '';
    $http_config .= <<_EOC_;

    lua_package_path "$pwd/lib/?.lua;../lua-resty-lrucache/lib/?.lua;;";
    init_by_lua_block {
        require "resty.core"
    }
_EOC_
    $block->set_value("http_config", $http_config);
});

#no_diff();
no_long_string();
#check_accum_error_log();
run_tests();

__DATA__

=== TEST 1: sanity
--- http_config
    lua_intercept_error_log 4m;
--- config
    location /t {
        access_by_lua_block {
            ngx.log(ngx.ERR, "enter 1")
            ngx.log(ngx.ERR, "enter 11")

            local ngx_log = require "ngx.log"
            local res, err = ngx_log.get_errlog()
            if not res then
                error("FAILED " .. err)
            end
            ngx.say("log lines:", #res / 2)
        }
    }
--- request
GET /t
--- response_body
log lines:2
--- grep_error_log eval
qr/enter \d+/
--- grep_error_log_out eval
[
"enter 1
enter 11
",
"enter 1
enter 11
"
]
--- skip_nginx: 3: <1.11.2



=== TEST 2: overflow intercepted error logs
--- http_config
    lua_intercept_error_log 4k;
--- config
    location /t {
        access_by_lua_block {
            ngx.log(ngx.ERR, "enter 1")
            ngx.log(ngx.ERR, "enter 22" .. string.rep("a", 4096))

            local ngx_log = require "ngx.log"
            local res, err = ngx_log.get_errlog()
            if not res then
                error("FAILED " .. err)
            end
            ngx.say("log lines:", #res / 2)
        }
    }
--- request
GET /t
--- response_body
log lines:1
--- grep_error_log eval
qr/enter \d+/
--- grep_error_log_out eval
[
"enter 1
enter 22
",
"enter 1
enter 22
"
]
--- skip_nginx: 3: <1.11.2



=== TEST 3: 404 error(not found)
--- http_config
    lua_intercept_error_log 4m;
--- config
    log_by_lua_block {
        local ngx_log = require "ngx.log"
        local res, err = ngx_log.get_errlog()
        if not res then
            error("FAILED " .. err)
        end
        ngx.log(ngx.ERR, "intercept log line:", #res / 2)
    }
--- request
GET /t
--- error_code: 404
--- grep_error_log eval
qr/intercept log line:\d+|No such file or directory/
--- grep_error_log_out eval
[
qr/^No such file or directory
intercept log line:1
$/,
qr/^No such file or directory
intercept log line:2
$/
]
--- skip_nginx: 2: <1.11.2



=== TEST 4: 500 error
--- http_config
    lua_intercept_error_log 4m;
--- config
    location /t {
        content_by_lua_block {
            local t = {}/4
        }
    }
    log_by_lua_block {
        local ngx_log = require "ngx.log"
        local res, err = ngx_log.get_errlog()
        if not res then
            error("FAILED " .. err)
        end
        ngx.log(ngx.ERR, "intercept log line:", #res / 2)
    }
--- request
GET /t
--- error_code: 500
--- grep_error_log eval
qr/intercept log line:\d+|attempt to perform arithmetic on a table value/
--- grep_error_log_out eval
[
qr/^attempt to perform arithmetic on a table value
intercept log line:1
$/,
qr/^attempt to perform arithmetic on a table value
intercept log line:2
$/
]
--- skip_nginx: 2: <1.11.2



=== TEST 5: no error log
--- http_config
    lua_intercept_error_log 4m;
--- config
    location /t {
        echo "hello";
    }
    log_by_lua_block {
        local ngx_log = require "ngx.log"
        local res, err = ngx_log.get_errlog()
        if not res then
            error("FAILED " .. err)
        end
        ngx.log(ngx.ERR, "intercept log line:", #res / 2)
    }
--- request
GET /t
--- response_body
hello
--- grep_error_log eval
qr/intercept log line:\d+/
--- grep_error_log_out eval
[
qr/^intercept log line:0
$/,
qr/^intercept log line:1
$/
]
--- skip_nginx: 3: <1.11.2



=== TEST 6: customize the log path
--- http_config
    lua_intercept_error_log 4m;
    error_log logs/error_http.log error;
--- config
    location /t {
        error_log logs/error.log error;
        access_by_lua_block {
            ngx.log(ngx.ERR, "enter access /t")
        }
        echo "hello";
    }
    log_by_lua_block {
        local ngx_log = require "ngx.log"
        local res, err = ngx_log.get_errlog()
        if not res then
            error("FAILED " .. err)
        end
        ngx.log(ngx.ERR, "intercept log line:", #res / 2)

    }
--- request
GET /t
--- response_body
hello
--- grep_error_log eval
qr/intercept log line:\d+|enter access/
--- grep_error_log_out eval
[
qr/^enter access
intercept log line:1
$/,
qr/^enter access
intercept log line:2
$/
]
--- skip_nginx: 3: <1.11.2



=== TEST 7: invalid size (< 4k)
--- http_config
    lua_intercept_error_log 3k;
--- config
    location /t {
        echo "hello";
    }
--- must_die
--- error_log
invalid intercept error log size "3k", minimum size is 4096
--- skip_nginx: 2: <1.11.2



=== TEST 8: invalid size (no argu)
--- http_config
    lua_intercept_error_log;
--- config
    location /t {
        echo "hello";
    }
--- must_die
--- error_log
invalid number of arguments in "lua_intercept_error_log" directive
--- skip_nginx: 2: <1.11.2



=== TEST 9: without directive + ngx.errlog
--- config
    location /t {
        access_by_lua_block {
            ngx.log(ngx.ERR, "enter 1")

            local ngx_log = require "ngx.log"
            local res, err = ngx_log.get_errlog()
            if not res then
                error("FAILED " .. err)
            end
            ngx.say("log lines:", #res / 2)
        }
    }
--- request
GET /t
--- response_body_like: 500 Internal Server Error
--- error_code: 500
--- error_log
API "get_errlog_data" depends on directive "lua_intercept_error_log"
--- skip_nginx: 3: <1.11.2



=== TEST 10: without directive + ngx.set_errlog_filter
--- config
    location /t {
        access_by_lua_block {
            local ngx_log = require "ngx.log"
            local status, err = ngx_log.set_errlog_filter(ngx.ERR)
            if not status then
                error(err)
            end
        }
    }
--- request
GET /t
--- response_body_like: 500 Internal Server Error
--- error_code: 500
--- error_log
API "set_errlog_filter" depends on directive "lua_intercept_error_log"
--- skip_nginx: 3: <1.11.2



=== TEST 11: filter log by level(ngx.INFO)
--- http_config
    lua_intercept_error_log 4m;
--- config
    location /t {
        access_by_lua_block {
            local ngx_log = require "ngx.log"
            local status, err = ngx_log.set_errlog_filter(ngx.INFO)
            if not status then
                error(err)
            end

            ngx.log(ngx.INFO, "-->1")
            ngx.log(ngx.WARN, "-->2")
            ngx.log(ngx.ERR, "-->3")
        }
        content_by_lua_block {
            local ngx_log = require "ngx.log"
            local res = ngx_log.get_errlog()
            ngx.say("log lines:", #res / 2)
        }
    }
--- log_level: info
--- request
GET /t
--- response_body
log lines:3
--- grep_error_log eval
qr/-->\d+/
--- grep_error_log_out eval
[
"-->1
-->2
-->3
",
"-->1
-->2
-->3
"
]
--- skip_nginx: 3: <1.11.2



=== TEST 12: filter log by level(ngx.WARN)
--- http_config
    lua_intercept_error_log 4m;
--- config
    location /t {
        access_by_lua_block {
            local ngx_log = require "ngx.log"
            local status, err = ngx_log.set_errlog_filter(ngx.WARN)
            if not status then
                error(err)
            end

            ngx.log(ngx.INFO, "-->1")
            ngx.log(ngx.WARN, "-->2")
            ngx.log(ngx.ERR, "-->3")
        }
        content_by_lua_block {
            local ngx_log = require "ngx.log"
            local res = ngx_log.get_errlog()
            ngx.say("log lines:", #res / 2)
        }
    }
--- log_level: info
--- request
GET /t
--- response_body
log lines:2
--- grep_error_log eval
qr/-->\d+/
--- grep_error_log_out eval
[
"-->1
-->2
-->3
",
"-->1
-->2
-->3
"
]
--- skip_nginx: 3: <1.11.2



=== TEST 13: filter log by level(ngx.CRIT)
--- http_config
    lua_intercept_error_log 4m;
--- log_level: info
--- config
    location /t {
        access_by_lua_block {
            local ngx_log = require "ngx.log"
            local status, err = ngx_log.set_errlog_filter(ngx.CRIT)
            if not status then
                error(err)
            end

            ngx.log(ngx.INFO, "-->1")
            ngx.log(ngx.WARN, "-->2")
            ngx.log(ngx.ERR, "-->3")
        }
        content_by_lua_block {
            local ngx_log = require "ngx.log"
            local res = ngx_log.get_errlog()
            ngx.say("log lines:", #res / 2)
        }
    }
--- request
GET /t
--- response_body
log lines:0
--- grep_error_log eval
qr/-->\d+/
--- grep_error_log_out eval
[
"-->1
-->2
-->3
",
"-->1
-->2
-->3
"
]
--- skip_nginx: 3: <1.11.2



=== TEST 14: set max count and reuse table
--- http_config
    lua_intercept_error_log 4m;
--- config
    location /t {
        access_by_lua_block {
            tab_clear = require "table.clear"
            ngx.log(ngx.ERR, "enter 1")
            ngx.log(ngx.ERR, "enter 22")
            ngx.log(ngx.ERR, "enter 333")

            local ngx_log = require "ngx.log"
            local res = {}
            local err
            res, err = ngx_log.get_errlog(2, res)
            if not res then
                error("FAILED " .. err)
            end
            ngx.say("log lines:", #res / 2)

            tab_clear(res)
            res, err = ngx_log.get_errlog(2, res)
            if not res then
                error("FAILED " .. err)
            end
            ngx.say("log lines:", #res / 2)
        }
    }
--- request
GET /t
--- response_body
log lines:2
log lines:1
--- skip_nginx: 2: <1.11.2



=== TEST 15: wrong argument
--- http_config
    lua_intercept_error_log 4m;
--- config
    location /t {
        access_by_lua_block {
            local ngx_log = require "ngx.log"
            local status, err = ngx_log.set_errlog_filter()
            if not status then
                error(err)
            end
        }
    }
--- request
GET /t
--- error_code: 500
--- response_body_like: 500
--- grep_error_log eval
qr/missing \"level\" argument/
--- grep_error_log_out eval
[
"missing \"level\" argument
",
"missing \"level\" argument
",
]
--- skip_nginx: 3: <1.11.2
