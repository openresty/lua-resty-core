# vim:set ft= ts=4 sw=4 et fdm=marker:
use lib '.';
use t::TestCore;

#worker_connections(10140);
#workers(1);
#log_level('warn');

repeat_each(2);

# All these tests need to have new openssl
my $NginxBinary = $ENV{'TEST_NGINX_BINARY'} || 'nginx';
my $openssl_version = eval { `$NginxBinary -V 2>&1` };

if ($openssl_version =~ m/built with OpenSSL (0|1\.0\.(?:0|1[^\d]|2[a-d]).*)/) {
    plan(skip_all => "too old OpenSSL, need >= 1.0.2e, was $1");
} else {
    plan tests => repeat_each() * (blocks() * 3);
}

no_long_string();
#no_diff();

env_to_nginx("PATH=" . $ENV{'PATH'});
$ENV{TEST_NGINX_LUA_PACKAGE_PATH} = "$t::TestCore::lua_package_path";
$ENV{TEST_NGINX_HTML_DIR} ||= html_dir();

run_tests();

__DATA__

=== TEST 1: ssl.proxysslcert.clear_certs
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";

    server {
        listen unix:$TEST_NGINX_HTML_DIR/nginx.sock ssl;
        server_name   test.com;

        ssl_protocols TLSv1.3;
        ssl_verify_client on;
        ssl_certificate ../../cert/mtls_server.crt;
        ssl_certificate_key ../../cert/mtls_server.key;
        ssl_client_certificate ../../cert/mtls_ca.crt;

        location / {
            default_type 'text/plain';

            content_by_lua_block {
                ngx.say("hello world")
            }

            more_clear_headers Date;
        }
    }
--- config
    location /t {
        proxy_pass                    https://unix:$TEST_NGINX_HTML_DIR/nginx.sock;
        proxy_ssl_verify              on;
        proxy_ssl_name                example.com;
        proxy_ssl_certificate         ../../cert/mtls_client.crt;
        proxy_ssl_certificate_key     ../../cert/mtls_client.key;
        proxy_ssl_trusted_certificate ../../cert/mtls_ca.crt;
        proxy_ssl_session_reuse       off;
        proxy_ssl_conf_command        VerifyMode Peer;

        proxy_ssl_certificate_by_lua_block {
            local proxy_ssl_cert = require "ngx.ssl.proxysslcert"

            proxy_ssl_cert.clear_certs()
        }
    }
--- request
GET /t
--- error_code: 400
--- response_body_like: 400 No required SSL certificate was sent
--- no_error_log
[alert]



=== TEST 2: ssl.proxysslcert.set_der_cert & ssl.proxysslcert.set_der_priv_key
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";

    server {
        listen unix:$TEST_NGINX_HTML_DIR/nginx.sock ssl;
        server_name   test.com;

        ssl_protocols TLSv1.3;
        ssl_verify_client on;
        ssl_certificate ../../cert/mtls_server.crt;
        ssl_certificate_key ../../cert/mtls_server.key;
        ssl_client_certificate ../../cert/test.crt;

        location / {
            default_type 'text/plain';

            content_by_lua_block {
                ngx.say("hello world")
            }

            more_clear_headers Date;
        }
    }
--- config
    location /t {
        proxy_pass                    https://unix:$TEST_NGINX_HTML_DIR/nginx.sock;
        proxy_ssl_verify              on;
        proxy_ssl_name                example.com;
        proxy_ssl_trusted_certificate ../../cert/mtls_ca.crt;
        proxy_ssl_session_reuse       off;
        proxy_ssl_conf_command        VerifyMode Peer;

        proxy_ssl_certificate_by_lua_block {
            local ssl = require "ngx.ssl"
            local proxy_ssl_cert = require "ngx.ssl.proxysslcert"

            proxy_ssl_cert.clear_certs()

            local f = assert(io.open("t/cert/test.crt.der"))
            local cert_data = f:read("*a")
            f:close()

            local ok, err = proxy_ssl_cert.set_der_cert(cert_data)
            if not ok then
                ngx.log(ngx.ERR, "failed to set DER cert: ", err)
                return
            end

            local f = assert(io.open("t/cert/test.key.der"))
            local pkey_data = f:read("*a")
            f:close()

            local ok, err = proxy_ssl_cert.set_der_priv_key(pkey_data)
            if not ok then
                ngx.log(ngx.ERR, "failed to set DER cert: ", err)
                return
            end
        }
    }
--- request
GET /t
--- error_code: 200
--- response_body
hello world
--- no_error_log
[alert]



=== TEST 3: ssl.proxysslcert.set_cert & ssl.proxysslcert.set_priv_key
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";

    server {
        listen unix:$TEST_NGINX_HTML_DIR/nginx.sock ssl;
        server_name   test.com;

        ssl_protocols TLSv1.3;
        ssl_verify_client on;
        ssl_certificate ../../cert/mtls_server.crt;
        ssl_certificate_key ../../cert/mtls_server.key;
        ssl_client_certificate ../../cert/mtls_ca.crt;

        location / {
            default_type 'text/plain';

            content_by_lua_block {
                ngx.say("hello world")
            }

            more_clear_headers Date;
        }
    }
--- config
    location /t {
        proxy_pass                    https://unix:$TEST_NGINX_HTML_DIR/nginx.sock;
        proxy_ssl_verify              on;
        proxy_ssl_name                example.com;
        proxy_ssl_trusted_certificate ../../cert/mtls_ca.crt;
        proxy_ssl_session_reuse       off;
        proxy_ssl_conf_command        VerifyMode Peer;

        proxy_ssl_certificate_by_lua_block {
            local ssl = require "ngx.ssl"
            local proxy_ssl_cert = require "ngx.ssl.proxysslcert"

            local f = assert(io.open("t/cert/mtls_client.crt"))
            local cert_data = f:read("*a")
            f:close()

            local cert, err = ssl.parse_pem_cert(cert_data)
            if not cert then
                ngx.log(ngx.ERR, "failed to parse pem cert: ", err)
                return
            end

            local ok, err = proxy_ssl_cert.set_cert(cert)
            if not ok then
                ngx.log(ngx.ERR, "failed to set cert: ", err)
                return
            end

            local f = assert(io.open("t/cert/mtls_client.key"))
            local pkey_data = f:read("*a")
            f:close()

            local pkey, err = ssl.parse_pem_priv_key(pkey_data)
            if not pkey then
                ngx.log(ngx.ERR, "failed to parse pem key: ", err)
                return
            end

            local ok, err = proxy_ssl_cert.set_priv_key(pkey)
            if not ok then
                ngx.log(ngx.ERR, "failed to set private key: ", err)
                return
            end
        }
    }
--- request
GET /t
--- error_code: 200
--- response_body
hello world
--- no_error_log
[alert]
