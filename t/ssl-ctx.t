# vim:set ft= ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);
use Digest::MD5 qw(md5_hex);

repeat_each(2);

plan tests => repeat_each() * (blocks() + 6);

our $CWD = cwd();
$ENV{TEST_NGINX_LUA_PACKAGE_PATH} = "$::CWD/lib/?.lua;;";
$ENV{TEST_NGINX_HTML_DIR} ||= html_dir();
our $TEST_NGINX_LUA_PACKAGE_PATH = $ENV{TEST_NGINX_LUA_PACKAGE_PATH};
our $TEST_NGINX_HTML_DIR = $ENV{TEST_NGINX_HTML_DIR};

log_level 'debug';

no_long_string();

sub read_file {
    my $infile = shift;
    open my $in, $infile
        or die "cannot open $infile for reading: $!";
    my $cert = do { local $/; <$in> };
    close $in;
    $cert;
}

our $clientKey = read_file("t/cert/ca-client-server/client.key");
our $clientUnsecureKey = read_file("t/cert/ca-client-server/client.unsecure.key");
our $clientCrt = read_file("t/cert/ca-client-server/client.crt");
our $clientCrtMd5 = md5_hex($clientCrt);
our $serverKey = read_file("t/cert/ca-client-server/server.key");
our $serverUnsecureKey = read_file("t/cert/ca-client-server/server.unsecure.key");
our $serverCrt = read_file("t/cert/ca-client-server/server.crt");
our $caKey = read_file("t/cert/ca-client-server/ca.key");
our $caCrt = read_file("t/cert/ca-client-server/ca.crt");
our $http_config = <<_EOS_;
lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH/?.lua;;../lua-resty-lrucache/lib/?.lua;";

init_by_lua_block {
    require "resty.core.socket.tcp"

    function read_file(file)
        local f = io.open(file, "rb")
        local content = f:read("*all")
        f:close()
        return content
    end

    local lrucache = require "resty.lrucache"
    local c, err = lrucache.new(1)
    if not c then
        return error("failed to create the cache: " .. (err or "unknown"))
    end
    local ssl = require "ngx.ssl"
    local cert =  ssl.parse_pem_cert(read_file("$TEST_NGINX_HTML_DIR/client.crt"))
    local priv_key = ssl.parse_pem_priv_key(read_file("$TEST_NGINX_HTML_DIR/client.unsecure.key"))

    local ssl_ctx, err = ssl.create_ctx({
        priv_key = priv_key,
        cert = cert
    })

    c:set("sslctx", ssl_ctx)

    function lrucache_getsslctx()
        return c:get("sslctx")
    end

    function get_response_body(response)
        for k, v in ipairs(response) do
            if #v == 0 then
                return table.concat(response, "\\r\\n", k + 1)
            end
        end

        return nil, "CRLF not found"
    end

    function https_get(host, port, path, ssl_ctx)
        local sock = ngx.socket.tcp()

        local ok, err = sock:connect(host, port)
        if not ok then
            return nil, err
        end

        local ok, err = sock:setsslctx(ssl_ctx)
        if not ok then
            return nil, err
        end

        local sess, err = sock:sslhandshake()
        if not sess then
            return nil, err
        end

        local req = "GET " .. path .. " HTTP/1.0\\r\\nHost: server\\r\\nConnection: close\\r\\n\\r\\n"
        local bytes, err = sock:send(req)
        if not bytes then
            return nil, err
        end

        local response = {}
        while true do
            local line, err, partial = sock:receive()
            if not line then
                if not partial then
                    response[#response+1] = partial
                end
                break
            end

            response[#response+1] = line
        end

        sock:close()

        return response
    end
}
server {
    listen 1983 ssl;
    server_name   server;
    ssl_certificate ../html/server.crt;
    ssl_certificate_key ../html/server.unsecure.key;

    ssl on;
    ssl_client_certificate ../html/ca.crt;
    ssl_verify_client on;

    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;

    ssl_prefer_server_ciphers  on;

    server_tokens off;
    more_clear_headers Date;
    default_type 'text/plain';

    location / {
        content_by_lua_block {
            ngx.say("foo")
        }
    }

    location /protocol {
        content_by_lua_block {ngx.say(ngx.var.ssl_protocol)}
    }

    location /cert {
        content_by_lua_block {
            ngx.say(ngx.md5(ngx.var.ssl_client_raw_cert))
        }
    }
}
_EOS_
our $user_files = <<_EOS_;
>>> client.key
$clientKey
>>> client.unsecure.key
$clientUnsecureKey
>>> client.crt
$clientCrt
>>> server.key
$serverKey
>>> server.unsecure.key
$serverUnsecureKey
>>> server.crt
$serverCrt
>>> ca.key
$caKey
>>> ca.crt
$caCrt
>>> wrong.crt
OpenResty
>>> wrong.key
OpenResty
_EOS_

add_block_preprocessor(sub {
    my $block = shift;

    $block->set_value("http_config", $http_config);
    $block->set_value("user_files", $user_files);
});

run_tests();

__DATA__

=== TEST 1: ssl ctx - create_ctx must pass options
--- config
    location /t{
        content_by_lua_block {
            local ssl = require "ngx.ssl"
            local ssl_ctx, err = ssl.create_ctx()
            if ssl_ctx == nil then
                ngx.say(err)
            end
        }
    }
--- request
GET /t
--- response_body
no options found



=== TEST 2: ssl ctx - specify ssl protocols TLSv1、TLSv1.1、TLSv1.2
--- config
    location /t {
        content_by_lua_block {
            local ssl = require "ngx.ssl"
            function test_ssl_protocol(protocols)
                local ssl = require "ngx.ssl"
                local cert = ssl.parse_pem_cert(read_file("$TEST_NGINX_HTML_DIR/client.crt"))
                local priv_key = ssl.parse_pem_priv_key(read_file("$TEST_NGINX_HTML_DIR/client.unsecure.key"))
                local ssl_ctx, err = ssl.create_ctx({
                    protocols = protocols,
                    priv_key = priv_key,
                    cert = cert
                })
                if ssl_ctx == nil then
                    return err
                end

                local response, err = https_get('127.0.0.1', 1983, '/protocol', ssl_ctx)

                if not response then
                    return err
                end

                local body, err = get_response_body(response)
                if not body then
                    return err
                end
                return body
            end

            local bit = require "bit"
            local bor = bit.bor

            ngx.say(test_ssl_protocol(ssl.PROTOCOL_TLSv1))
            ngx.say(test_ssl_protocol(ssl.PROTOCOL_TLSv1_1))
            ngx.say(test_ssl_protocol(ssl.PROTOCOL_TLSv1_2))
            ngx.say(test_ssl_protocol(bor(ssl.PROTOCOL_SSLv2, ssl.PROTOCOL_TLSv1_2)))
        }
    }

--- request
GET /t
--- response_body
TLSv1
TLSv1.1
TLSv1.2
TLSv1.2

--- no_error_log
[error]



=== TEST 3: ssl ctx - dismatch priv_key and cert
--- config
    location /t {
        content_by_lua_block {
            local ssl = require "ngx.ssl"
            local cert = ssl.parse_pem_cert(read_file("$TEST_NGINX_HTML_DIR/server.crt"))
            local priv_key = ssl.parse_pem_priv_key(read_file("$TEST_NGINX_HTML_DIR/client.unsecure.key"))
            local ssl_ctx, err = ssl.create_ctx({
                priv_key = priv_key,
                cert = cert
            })
            if ssl_ctx == nil then
                ngx.say("create_ctx err: ", err)
            end
        }
    }

--- request
GET /t
--- response_body
create_ctx err: SSL_CTX_use_PrivateKey() failed



=== TEST 4: ssl ctx - send client certificate
--- config
    location /t {
        content_by_lua_block {
            local ssl = require "ngx.ssl"
            local cert =  ssl.parse_pem_cert(read_file("$TEST_NGINX_HTML_DIR/client.crt"))
            local priv_key = ssl.parse_pem_priv_key(read_file("$TEST_NGINX_HTML_DIR/client.unsecure.key"))

            local ssl_ctx, err = ssl.create_ctx({
                priv_key = priv_key,
                cert = cert
            })

            if ssl_ctx == nil then
                ngx.say("failed to init ssl ctx: ", err)
                return
            end
            local response = https_get("127.0.0.1", 1983, "/cert", ssl_ctx)
            ngx.say(get_response_body(response))
        }
    }
--- request
GET /t
--- response_body eval
"$::clientCrtMd5
"



=== TEST 5: ssl ctx - setsslctx with cached ssl_ctx
--- config
    location /t {
        content_by_lua_block {
            local ssl_ctx = lrucache_getsslctx()
            local response = https_get("127.0.0.1", 1983, "/cert", ssl_ctx)
            ngx.say(get_response_body(response))
        }
    }
--- request
GET /t
--- response_body eval
"$::clientCrtMd5
"
