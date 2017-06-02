# vim:set ft= ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);
use Digest::MD5 qw(md5_hex);

repeat_each(2);

plan tests => repeat_each() * (blocks() + 14);

our $CWD = cwd();
$ENV{TEST_NGINX_LUA_PACKAGE_PATH} = "$::CWD/lib/?.lua;;";
$ENV{TEST_NGINX_HTML_DIR} ||= html_dir();
$ENV{TEST_NGINX_RESOLVER} ||= '8.8.8.8';
our $TEST_NGINX_LUA_PACKAGE_PATH = $ENV{TEST_NGINX_LUA_PACKAGE_PATH};
our $TEST_NGINX_HTML_DIR = $ENV{TEST_NGINX_HTML_DIR};

log_level 'debug';

sub read_file {
    my $infile = shift;
    open my $in, $infile
        or die "cannot open $infile for reading: $!";
    my $cert = do { local $/; <$in> };
    close $in;
    $cert;
}

our $system_cert_path = "/etc/pki/tls/cert.pem";

if (-e "/usr/local/share/ca-certificates/ca.crt") {
    $system_cert_path = "/usr/local/share/ca-certificates/ca.crt";
}

if (-e "/etc/ssl/certs/ca-certificates.crt") {
    $system_cert_path = "/etc/ssl/certs/ca-certificates.crt";
}

our $SystemCerts = read_file($system_cert_path);
our $TestCertificate = read_file("t/cert/test.crt");
our $TestCertificateKey = read_file("t/cert/test.key");
our $TestCRL = read_file("t/cert/test.crl");
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
        if f == nil then
            return error(file)
        end
        local content = f:read("*all")
        f:close()
        return content
    end

    local lrucache = require "resty.lrucache"
    local c, err = lrucache.new(10)
    if not c then
        return error("failed to create the cache: " .. (err or "unknown"))
    end
    local ssl = require "ngx.ssl"
    local cert =  ssl.parse_pem_cert(read_file("$TEST_NGINX_HTML_DIR/client.crt"))
    local priv_key = ssl.parse_pem_priv_key(read_file("$TEST_NGINX_HTML_DIR/client.unsecure.key"))

    local ssl_ctx, err = ssl.create_ctx{
        priv_key = priv_key,
        cert = cert
    }

    c:set("sslctx", ssl_ctx)

    local system_cert =  read_file("$system_cert_path")
    local cert_store, err = ssl.create_x509_store(system_cert)
    if cert_store == nil then
        return ngx.say(err)
    end

    c:set("cert_store", cert_store)

    function lrucache_getsslctx()
        return c:get("sslctx")
    end

    function lrucache_getcertstore()
        return c:get("cert_store")
    end

    function get_response_body(response)
        for k, v in ipairs(response) do
            if #v == 0 then
                return table.concat(response, "\\r\\n", k + 1)
            end
        end

        return nil, "CRLF not found"
    end

    function https_get(host, port, domain, path, ssl_ctx, verify)
        local sock = ngx.socket.tcp()
        domain = domain or "server"
        verify = verify or false

        local ok, err = sock:connect(host, port)
        if not ok then
            return nil, err
        end

        local ok, err = sock:setsslctx(ssl_ctx)
        if not ok then
            return nil, err
        end

        local sess, err = sock:sslhandshake(nil, domain, verify)
        if not sess then
            return nil, err
        end

        local req = "GET " .. path .. " HTTP/1.0\\r\\nHost: " .. domain .. "\\r\\nConnection: close\\r\\n\\r\\n"
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

    location /cipher {
        content_by_lua_block {
            ngx.say(ngx.var.ssl_cipher)
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
>>> system.crt
$SystemCerts
_EOS_

add_block_preprocessor(sub {
    my $block = shift;

    if (!defined $block->http_config) {
        $block->set_value("http_config", $http_config);
    }

    if (!defined $block->user_files) {
        $block->set_value("user_files", $user_files);
    }
});


no_shuffle();
no_long_string();
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
                local ssl_ctx, err = ssl.create_ctx{
                    protocols = protocols,
                    priv_key = priv_key,
                    cert = cert
                }
                if ssl_ctx == nil then
                    return err
                end

                local response, err = https_get('127.0.0.1', 1983, 'server', '/protocol', ssl_ctx)

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

            ngx.say(test_ssl_protocol(ssl.TLSv1))
            ngx.say(test_ssl_protocol(ssl.TLSv1_1))
            ngx.say(test_ssl_protocol(ssl.TLSv1_2))
            ngx.say(test_ssl_protocol(bor(ssl.SSLv2, ssl.TLSv1_2)))
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
            local ssl_ctx, err = ssl.create_ctx{
                priv_key = priv_key,
                cert = cert
            }
            if ssl_ctx == nil then
                ngx.say(err)
            end
        }
    }

--- request
GET /t
--- response_body
error:0B080074:x509 certificate routines:X509_check_private_key:key values mismatch



=== TEST 4: ssl ctx - send client certificate
--- config
    location /t {
        content_by_lua_block {
            local ssl = require "ngx.ssl"
            local cert =  ssl.parse_pem_cert(read_file("$TEST_NGINX_HTML_DIR/client.crt"))
            local priv_key = ssl.parse_pem_priv_key(read_file("$TEST_NGINX_HTML_DIR/client.unsecure.key"))

            local ssl_ctx, err = ssl.create_ctx{
                priv_key = priv_key,
                cert = cert
            }

            if ssl_ctx == nil then
                ngx.say("failed to init ssl ctx: ", err)
                return
            end
            local response = https_get("127.0.0.1", 1983, "server", "/cert", ssl_ctx)
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
            local response = https_get("127.0.0.1", 1983, "server", "/cert", ssl_ctx)
            ngx.say(get_response_body(response))
        }
    }
--- request
GET /t
--- response_body eval
"$::clientCrtMd5
"



=== TEST 6: ssl ctx - set error ciphers
--- config
    location /t {
        content_by_lua_block {
            local ssl = require "ngx.ssl"
            local cert =  ssl.parse_pem_cert(read_file("$TEST_NGINX_HTML_DIR/client.crt"))
            local priv_key = ssl.parse_pem_priv_key(read_file("$TEST_NGINX_HTML_DIR/client.unsecure.key"))

            local ssl_ctx, err = ssl.create_ctx{
                priv_key = priv_key,
                cert = cert,
                ciphers = "ECDHE-RSA-AES256-SHA-openresty",
            }

            if ssl_ctx == nil then
                ngx.say("failed to init ssl ctx: ", err)
                return
            end
            local response = https_get("127.0.0.1", 1983, "server", "/ciphers", ssl_ctx)
            ngx.say(get_response_body(response))
        }
    }
--- request
GET /t
--- response_body
failed to init ssl ctx: error:1410D0B9:SSL routines:SSL_CTX_set_cipher_list:no cipher match



=== TEST 7: ssl ctx - set right ciphers
--- config
    location /t {
        content_by_lua_block {
            local ssl = require "ngx.ssl"
            local cert =  ssl.parse_pem_cert(read_file("$TEST_NGINX_HTML_DIR/client.crt"))
            local priv_key = ssl.parse_pem_priv_key(read_file("$TEST_NGINX_HTML_DIR/client.unsecure.key"))

            local ssl_ctx, err = ssl.create_ctx{
                priv_key = priv_key,
                cert = cert,
                ciphers = "ECDHE-RSA-AES256-SHA",
            }

            if ssl_ctx == nil then
                ngx.say("failed to init ssl ctx: ", err)
                return
            end
            local response = https_get("127.0.0.1", 1983, "server", "/cipher", ssl_ctx)
            ngx.say(get_response_body(response))
        }
    }
--- request
GET /t
--- response_body
ECDHE-RSA-AES256-SHA



=== TEST 8: ssl ctx - set ca cert
--- config
    location /t {
        content_by_lua_block {
            local ssl = require "ngx.ssl"
            local ca =  read_file("$TEST_NGINX_HTML_DIR/ca.crt")
            local cert =  ssl.parse_pem_cert(read_file("$TEST_NGINX_HTML_DIR/client.crt"))
            local priv_key = ssl.parse_pem_priv_key(read_file("$TEST_NGINX_HTML_DIR/client.unsecure.key"))

            local ssl_ctx, err = ssl.create_ctx{
                priv_key = priv_key,
                cert = cert,
                ca = ca
            }

            if ssl_ctx == nil then
                ngx.say("failed to init ssl ctx: ", err)
                return
            end
            local response = https_get("127.0.0.1", 1983, "server", "/", ssl_ctx)
            ngx.say(get_response_body(response))

            local no_ca_ssl_ctx, err = ssl.create_ctx{
                priv_key = priv_key,
                cert = cert,
            }

            if ssl_ctx == nil then
                ngx.say("failed to init ssl ctx: ", err)
                return
            end
            local response, err = https_get("127.0.0.1", 1983, "server", "/", no_ca_ssl_ctx, true)
            ngx.say(err)
        }
    }
--- request
GET /t
--- response_body
foo
20: unable to get local issuer certificate



=== TEST 9: ssl ctx - set crl
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH/?.lua;;../lua-resty-lrucache/lib/?.lua;";
    server {
        listen 1985 ssl;
        server_name   test.com;
        ssl_certificate ../html/test.crt;
        ssl_certificate_key ../html/test.key;

        location / {
            content_by_lua_block {ngx.say("hello")}
        }
    }
--- config
    location /t {
        content_by_lua_block {
            require "resty.core"
            function read_file(file)
                local f = io.open(file, "rb")
                local content = f:read("*all")
                f:close()
                return content
            end

            local ssl = require "ngx.ssl"
            local crl = read_file("$TEST_NGINX_HTML_DIR/test.crl");
            local server_cert = read_file("$TEST_NGINX_HTML_DIR/test.crt");

            local ssl_ctx, err = ssl.create_ctx{
                crl = crl,
                ca = server_cert,
            }

            if ssl_ctx == nil then
                ngx.say("failed to init ssl ctx: ", err)
                return
            end

            local sock = ngx.socket.tcp()
            local ok, err = sock:connect("127.0.0.1", 1985)
            if not ok then
                return ngx.say(err)
            end

            local ok, err = sock:setsslctx(ssl_ctx)
            if not ok then
                return ngx.say(err)
            end

            local sess, err = sock:sslhandshake(nil, "test.com", true)
            return ngx.say("sslhandshake:", err)
        }
    }

--- request
GET /t
--- response_body
sslhandshake:12: CRL has expired
--- user_files eval
">>> test.key
$::TestCertificateKey
>>> test.crt
$::TestCertificate
>>> test.crl
$::TestCRL"



=== TEST 10: ssl ctx - set cert store
--- config
    location /t {
        content_by_lua_block {
            local ssl = require "ngx.ssl"
            local ca =  read_file("$TEST_NGINX_HTML_DIR/ca.crt")
            local cert =  ssl.parse_pem_cert(read_file("$TEST_NGINX_HTML_DIR/client.crt"))
            local priv_key = ssl.parse_pem_priv_key(read_file("$TEST_NGINX_HTML_DIR/client.unsecure.key"))

            local no_cert_store_ssl_ctx, err = ssl.create_ctx{
                priv_key = priv_key,
                cert = cert,
            }

            if no_cert_store_ssl_ctx == nil then
                ngx.say("failed to init ssl ctx: ", err)
                return
            end
            local response, err = https_get("127.0.0.1", 1983, "server", "/",
                                            no_cert_store_ssl_ctx, true)
            ngx.say(err)

            local cert_store, err = ssl.create_x509_store(ca)
            if cert_store == nil then
                return ngx.say(err)
            end

            local ssl_ctx, err = ssl.create_ctx{
                priv_key = priv_key,
                cert = cert,
                cert_store = cert_store
            }

            if ssl_ctx == nil then
                ngx.say("failed to init ssl ctx: ", err)
                return
            end
            local response = https_get("127.0.0.1", 1983, "server", "/", ssl_ctx)
            ngx.say(get_response_body(response))
        }
    }
--- request
GET /t
--- response_body
20: unable to get local issuer certificate
foo



=== TEST 11: ssl ctx - set cert store with system cert
--- config
    resolver $TEST_NGINX_RESOLVER;
    location /t {
        content_by_lua_block {
            local ssl = require "ngx.ssl"
            local ca =  read_file("$TEST_NGINX_HTML_DIR/system.crt")
            local cert =  ssl.parse_pem_cert(read_file("$TEST_NGINX_HTML_DIR/client.crt"))
            local priv_key = ssl.parse_pem_priv_key(read_file("$TEST_NGINX_HTML_DIR/client.unsecure.key"))

            local no_cert_store_ssl_ctx, err = ssl.create_ctx{
                priv_key = priv_key,
                cert = cert,
            }

            if no_cert_store_ssl_ctx == nil then
                ngx.say("failed to init ssl ctx: ", err)
                return
            end

            local response, err = https_get("openresty.org", 443, "openresty.org", "/",
                                            no_cert_store_ssl_ctx, true)

            ngx.say(err)

            local cert_store, err = ssl.create_x509_store(ca)
            if cert_store == nil then
                return ngx.say(err)
            end

            local ssl_ctx, err = ssl.create_ctx{
                priv_key = priv_key,
                cert = cert,
                cert_store = cert_store
            }

            if ssl_ctx == nil then
                ngx.say("failed to init ssl ctx: ", err)
                return
            end
            local response, err = https_get("openresty.org", 443, "openresty.org", "/", ssl_ctx, true)
            if not err then
                ngx.say("success")
            else
                ngx.say("failed")
            end
        }
    }
--- request
GET /t
--- response_body
20: unable to get local issuer certificate
success
--- timeout: 5


=== TEST 12: ssl ctx - set cert store with lrucache
--- config
    resolver $TEST_NGINX_RESOLVER;
    location /t {
        content_by_lua_block {
            local ssl = require "ngx.ssl"
            local ca =  read_file("$TEST_NGINX_HTML_DIR/system.crt")
            local cert =  ssl.parse_pem_cert(read_file("$TEST_NGINX_HTML_DIR/client.crt"))
            local priv_key = ssl.parse_pem_priv_key(read_file("$TEST_NGINX_HTML_DIR/client.unsecure.key"))

            local cert_store = lrucache_getcertstore()
            local ssl_ctx, err = ssl.create_ctx{
                priv_key = priv_key,
                cert = cert,
                cert_store = cert_store
            }

            if ssl_ctx == nil then
                ngx.say("failed to init ssl ctx: ", err)
                return
            end
            local response, err = https_get("openresty.org", 443, "openresty.org", "/", ssl_ctx, true)
            if not err then
                ngx.say("success")
            else
                ngx.say("failed")
            end
        }
    }
--- request
GET /t
--- response_body
success
--- timeout: 5


=== TEST 13: ssl ctx - set cert store self-signed and system cert
--- config
--- config
    resolver $TEST_NGINX_RESOLVER;
    location /t {
        content_by_lua_block {
            local ssl = require "ngx.ssl"
            local system_cert =  read_file("$TEST_NGINX_HTML_DIR/system.crt")
            local local_cert  = read_file("$TEST_NGINX_HTML_DIR/ca.crt")
            local cert =  ssl.parse_pem_cert(read_file("$TEST_NGINX_HTML_DIR/client.crt"))
            local priv_key = ssl.parse_pem_priv_key(read_file("$TEST_NGINX_HTML_DIR/client.unsecure.key"))

            local cert_store, err = ssl.create_x509_store(local_cert, system_cert)
            if cert_store == nil then
                return ngx.say(err)
            end

            local ssl_ctx, err = ssl.create_ctx{
                priv_key = priv_key,
                cert = cert,
                cert_store = cert_store
            }

            if ssl_ctx == nil then
                ngx.say("failed to init ssl ctx: ", err)
                return
            end

            local response, err = https_get("openresty.org", 443, "openresty.org", "/", ssl_ctx, true)
            if not err then
                ngx.say("openresty.org success")
            else
                ngx.say("openresty.org failed: ", err)
            end
            local response, err = https_get("127.0.0.1", 1983, "server", "/", ssl_ctx, true)
            if not err then
                ngx.say("self-signed success")
            else
                ngx.say("self-signed failed: ", err)
            end
        }
    }
--- request
GET /t
--- response_body
openresty.org success
self-signed success
--- timeout: 5



=== TEST 14: ssl ctx - cert store init and free
--- config
    location /t {
        content_by_lua_block {
            local ssl = require "ngx.ssl"
            local local_cert  = read_file("$TEST_NGINX_HTML_DIR/ca.crt")
            local cert =  ssl.parse_pem_cert(read_file("$TEST_NGINX_HTML_DIR/client.crt"))
            local priv_key = ssl.parse_pem_priv_key(read_file("$TEST_NGINX_HTML_DIR/client.unsecure.key"))

            local cert_store, err = ssl.create_x509_store(local_cert)
            if cert_store == nil then
                return ngx.say(err)
            end
            cert_store = nil
            collectgarbage("collect")
        }
    }
--- request
GET /t
--- ignore_response
--- grep_error_log eval: qr/lua ssl x509 store (?:init|free): [0-9A-F]+:\d+/
--- grep_error_log_out eval
qr/^lua ssl x509 store init: ([0-9A-F]+):1
lua ssl x509 store free: ([0-9A-F]+):1
$/



=== TEST 15: ssl ctx - cert store init and up reference then free
--- config
    location /t {
        content_by_lua_block {
            local ssl = require "ngx.ssl"
            local local_cert  = read_file("$TEST_NGINX_HTML_DIR/ca.crt")
            local cert =  ssl.parse_pem_cert(read_file("$TEST_NGINX_HTML_DIR/client.crt"))
            local priv_key = ssl.parse_pem_priv_key(read_file("$TEST_NGINX_HTML_DIR/client.unsecure.key"))

            local cert_store, err = ssl.create_x509_store(local_cert)
            if cert_store == nil then
                return ngx.say(err)
            end

            local ssl_ctx, err = ssl.create_ctx{
                priv_key = priv_key,
                cert = cert,
                cert_store = cert_store
            }

            cert_store = nil
            collectgarbage("collect")
            ssl_ctx = nil
            collectgarbage("collect")
        }
    }
--- request
GET /t
--- ignore_response
--- grep_error_log eval: qr/lua ssl (?:x509 store|ctx) (?:init|free|up reference|x509 store reference): [0-9A-F]+:\d+/
--- grep_error_log_out eval
qr/^lua ssl x509 store init: ([0-9A-F]+):1
lua ssl ctx init: ([0-9A-F]+):1
lua ssl x509 store up reference: ([0-9A-F]+):2
lua ssl x509 store free: ([0-9A-F]+):2
lua ssl ctx x509 store reference: ([0-9A-F]+):1
lua ssl ctx free: ([0-9A-F]+):1
$/

