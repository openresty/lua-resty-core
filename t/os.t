# vim:set ft= ts=4 sw=4 et fdm=marker:
use lib 'lib';
use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

#worker_connections(1014);
#master_process_enabled(1);
#log_level('warn');

repeat_each(2);

plan tests => repeat_each() * (blocks() * 3);

our $pwd = cwd();

$ENV{MyTestSysEnv} = 'bar';


#no_diff();
#no_long_string();
check_accum_error_log();
run_tests();

__DATA__

=== TEST 1: env directive settings should be visible to init_by_lua*
--- main_config
env MyTestSysEnv=hello;
--- http_config eval
    "lua_package_path '$::pwd/lib/?.lua;;';
     init_by_lua_block {
       local v = require \"jit.v\"
       v.on(\"$Test::Nginx::Util::ErrLogFile\")
       require \"resty.core\"

       package.loaded.foo = os.getenv(\"MyTestSysEnv\")
     }
    "
--- config
location /t {
    content_by_lua_block {
        ngx.say(package.loaded.foo)
        ngx.say(os.getenv("MyTestSysEnv"))
    }
}
--- request
GET /t
--- response_body
hello
hello
--- no_error_log
[error]



=== TEST 2: use system environment
--- main_config
env MyTestSysEnv;
--- http_config eval
    "lua_package_path '$::pwd/lib/?.lua;;';
     init_by_lua_block {
       local v = require \"jit.v\"
       v.on(\"$Test::Nginx::Util::ErrLogFile\")
       require \"resty.core\"

       package.loaded.foo = os.getenv(\"MyTestSysEnv\")
     }
    "
--- config
location /t {
    content_by_lua_block {
        ngx.say(package.loaded.foo)
        ngx.say(os.getenv("MyTestSysEnv"))
    }
}
--- request
GET /t
--- response_body
bar
bar
--- no_error_log
[error]



=== TEST 3: test nil env
--- main_config
env baz;
--- http_config eval
    "lua_package_path '$::pwd/lib/?.lua;;';
     init_by_lua_block {
       local v = require \"jit.v\"
       v.on(\"$Test::Nginx::Util::ErrLogFile\")
       require \"resty.core\"

       package.loaded.foo = os.getenv(\"baz\")
     }
    "
--- config
location /t {
    content_by_lua_block {
        ngx.say(package.loaded.foo)
        ngx.say(os.getenv("baz"))
    }
}
--- request
GET /t
--- response_body
nil
nil
--- no_error_log
[error]
