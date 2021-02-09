package t::TestCore;

use Test::Nginx::Socket::Lua -Base;
use Cwd qw(cwd realpath abs_path);
use File::Basename;

$ENV{TEST_NGINX_HOTLOOP} ||= 10;
$ENV{TEST_NGINX_MEMCACHED_PORT} ||= 11211;
$ENV{TEST_NGINX_SERVER_SSL_PORT} ||= 23456;
$ENV{TEST_NGINX_CERT_DIR} ||= dirname(realpath(abs_path(__FILE__)));

our $pwd = cwd();

our $lua_package_path = './lib/?.lua;./t/lib/?.lua;../lua-resty-lrucache/lib/?.lua;;';

our $init_by_lua_block = <<_EOC_;
    local verbose = false
    if verbose then
        local dump = require "jit.dump"
        dump.on("b", "$Test::Nginx::Util::ErrLogFile")
    else
        local v = require "jit.v"
        v.on("$Test::Nginx::Util::ErrLogFile")
    end

    require "resty.core"
    jit.opt.start("hotloop=$ENV{TEST_NGINX_HOTLOOP}")
    -- jit.off()
_EOC_

our $HttpConfig = <<_EOC_;
    lua_package_path '$lua_package_path';

    init_by_lua_block {
        $t::TestCore::init_by_lua_block
    }
_EOC_

our @EXPORT = qw(
    $pwd
    $lua_package_path
    $init_by_lua_block
    $HttpConfig
);

add_block_preprocessor(sub {
    my $block = shift;

    if (!defined $block->http_config) {
        $block->set_value("http_config", $HttpConfig);
    }
});

1;
