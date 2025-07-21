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

if ($openssl_version =~ m/built with OpenSSL (0\S*|1\.0\S*|1\.1\.0\S*)/) {
    plan(skip_all => "too old OpenSSL, need 1.1.1, was $1");
} else {
    plan tests => repeat_each() * (blocks() * 6 - 2) - 4;
}

no_long_string();
#no_diff();

env_to_nginx("PATH=" . $ENV{'PATH'});
$ENV{TEST_NGINX_LUA_PACKAGE_PATH} = "$t::TestCore::lua_package_path";
$ENV{TEST_NGINX_HTML_DIR} ||= html_dir();

run_tests();

__DATA__

=== TEST 1: ssl.proxysslverify.set_verify_result & ssl.proxysslverify.get_verify_result
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";

    server {
        listen unix:$TEST_NGINX_HTML_DIR/nginx.sock ssl;

        ssl_certificate ../../cert/mtls_server.crt;
        ssl_certificate_key ../../cert/mtls_server.key;

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

        proxy_ssl_verify_by_lua_block {
            local proxy_ssl_vfy = require "ngx.ssl.proxysslverify"

            local ok, err = proxy_ssl_vfy.set_verify_result(23)
            if not ok then
                ngx.log(ngx.ERR, "proxy ssl verify set_verify_result failed: ", err)
                ngx.exit(ngx.ERROR)
            end

            local result, err = proxy_ssl_vfy.get_verify_result()
            if not result then
                ngx.log(ngx.ERR, "proxy ssl verify get_verify_result failed: ", err)
            end

            ngx.log(ngx.INFO, "proxy ssl verify result: ", result)
        }
    }
--- request
GET /t
--- error_code: 502
--- response_body_like: 502 Bad Gateway
--- error_log
proxy ssl verify result: 23
--- no_error_log
[alert]



=== TEST 2: ssl.proxysslverify.get_verify_cert
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";

    server {
        listen unix:$TEST_NGINX_HTML_DIR/nginx.sock ssl;

        ssl_certificate ../../cert/mtls_server.crt;
        ssl_certificate_key ../../cert/mtls_server.key;

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

        proxy_ssl_verify_by_lua_block {
            local proxy_ssl_vfy = require "ngx.ssl.proxysslverify"

            local cert, err = proxy_ssl_vfy.get_verify_cert()
            if not cert then
                ngx.log(ngx.ERR, "proxy ssl verify get_verify_cert failed: ", err)
            end

            -- more functions to take care of the returned cert
        }
    }
--- request
GET /t
--- error_code: 200
--- response_body
hello world
--- no_error_log
proxy ssl verify get_verify_cert failed
[alert]
