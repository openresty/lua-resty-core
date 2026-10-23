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

if ($openssl_version =~ m/built with OpenSSL (\d+)\.(\d+)\.(\d+)/) {
    my ($major, $minor, $patch) = ($1, $2, $3);

    if ($major < 4 || ($major == 4 && $minor < 1)) {
        plan(skip_all => "too old OpenSSL, need >= 4.1.0 was " .
            "$major.$minor.$patch");
    } else {
        plan tests => repeat_each() * (blocks() * 4);
    }
} elsif ($openssl_version =~ m/running with BoringSSL/) {
    plan(skip_all => "does not support BoringSSL");
} else {
    die "unknown SSL";
}

no_long_string();
#no_diff();

env_to_nginx("PATH=" . $ENV{'PATH'});
$ENV{TEST_NGINX_LUA_PACKAGE_PATH} = "$t::TestCore::lua_package_path";
$ENV{TEST_NGINX_HTML_DIR} ||= html_dir();

run_tests();

__DATA__

=== TEST 1: ssl.sslverify.set_verify_result & ssl.sslverify.get_verify_result
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";

    server {
        listen unix:$TEST_NGINX_HTML_DIR/nginx.sock ssl;
        server_name   test.com;
        ssl_verify_client on;
        ssl_certificate        ../../cert/mtls_server.crt;
        ssl_certificate_key    ../../cert/mtls_server.key;
        ssl_client_certificate ../../cert/mtls_ca.crt;

        ssl_verify_by_lua_block {
            local ssl_vfy = require "ngx.ssl.sslverify"

            local ok, err = ssl_vfy.set_verify_result(23)
            if not ok then
                ngx.log(ngx.ERR, "ssl verify set_verify_result failed: ", err)
                ngx.exit(ngx.ERROR)
            end

            local result, err = ssl_vfy.get_verify_result()
            if not result then
                ngx.log(ngx.ERR, "ssl verify get_verify_result failed: ", err)
            end

            ngx.log(ngx.INFO, "ssl verify result: ", result)
        }

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
        proxy_ssl_name                example.com;
        proxy_ssl_certificate         ../../cert/mtls_client.crt;
        proxy_ssl_certificate_key     ../../cert/mtls_client.key;
        proxy_ssl_trusted_certificate ../../cert/mtls_ca.crt;
        proxy_ssl_session_reuse       off;
    }
--- request
GET /t
--- error_code: 400
--- response_body_like: 400 The SSL certificate error
--- error_log
ssl verify result: 23
--- no_error_log
[alert]



=== TEST 2: ssl.sslverify.get_verify_cert
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";

    server {
        listen unix:$TEST_NGINX_HTML_DIR/nginx.sock ssl;
        server_name   test.com;
        ssl_verify_client on;
        ssl_certificate        ../../cert/mtls_server.crt;
        ssl_certificate_key    ../../cert/mtls_server.key;
        ssl_client_certificate ../../cert/mtls_ca.crt;

        ssl_verify_by_lua_block {
            local ssl_vfy = require "ngx.ssl.sslverify"

            local cert, err = ssl_vfy.get_verify_cert()
            if not cert then
                ngx.log(ngx.ERR, "ssl verify get_verify_cert failed: ", err)
            end

            -- more functions to take care of the returned cert
        }

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
        proxy_ssl_name                example.com;
        proxy_ssl_certificate         ../../cert/mtls_client.crt;
        proxy_ssl_certificate_key     ../../cert/mtls_client.key;
        proxy_ssl_trusted_certificate ../../cert/mtls_ca.crt;
        proxy_ssl_session_reuse       off;
    }
--- request
GET /t
--- error_code: 200
--- response_body
hello world
--- no_error_log
ssl verify get_verify_cert failed
[alert]



=== TEST 3: ssl.sslverify.set_verify_result & using $ssl_client_verify variable to get the verify result
--- http_config
    lua_package_path "$TEST_NGINX_LUA_PACKAGE_PATH";

    server {
        listen unix:$TEST_NGINX_HTML_DIR/nginx.sock ssl;
        server_name   test.com;
        ssl_verify_client on;
        ssl_certificate        ../../cert/mtls_server.crt;
        ssl_certificate_key    ../../cert/mtls_server.key;
        ssl_client_certificate ../../cert/mtls_ca.crt;

        ssl_verify_by_lua_block {
            local ssl_vfy = require "ngx.ssl.sslverify"

            -- according to openssl/include/openssl/x509_vfy.h
            -- #define X509_V_ERR_CERT_REVOKED  23
            local ok, err = ssl_vfy.set_verify_result(23)
            if not ok then
                ngx.log(ngx.ERR, "ssl verify set_verify_result failed: ", err)
                ngx.exit(ngx.ERROR)
            end
        }

        location / {
            default_type 'text/plain';

            content_by_lua_block {
                ngx.say("hello world")
            }

            more_clear_headers Date;
        }

	log_by_lua_block {
            ngx.log(ngx.ERR, "ssl verify result: ", ngx.var.ssl_client_verify)
	}
    }
--- config
    location /t {
        proxy_pass                    https://unix:$TEST_NGINX_HTML_DIR/nginx.sock;
        proxy_ssl_name                example.com;
        proxy_ssl_certificate         ../../cert/mtls_client.crt;
        proxy_ssl_certificate_key     ../../cert/mtls_client.key;
        proxy_ssl_trusted_certificate ../../cert/mtls_ca.crt;
        proxy_ssl_session_reuse       off;
    }
--- request
GET /t
--- error_code: 400
--- response_body_like: 400 The SSL certificate error
--- error_log
ssl verify result: FAILED:certificate revoked
--- no_error_log
[alert]
