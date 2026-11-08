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
    plan tests => repeat_each() * (blocks() * 5);
}

no_long_string();
#no_diff();

env_to_nginx("PATH=" . $ENV{'PATH'});
$ENV{TEST_NGINX_LUA_PACKAGE_PATH} = "$t::TestCore::lua_package_path";
$ENV{TEST_NGINX_HTML_DIR} ||= html_dir();

run_tests();

__DATA__

=== TEST 1: proxyssl.get_tls1_version and proxyssl.get_tls1_version_str
--- http_config
    server {
        listen unix:$TEST_NGINX_HTML_DIR/nginx.sock ssl;
        server_name   test.com;

        ssl_protocols TLSv1.2;
        ssl_verify_client on;
        ssl_certificate ../../cert/mtls_server.crt;
        ssl_certificate_key ../../cert/mtls_server.key;
        ssl_client_certificate ../../cert/mtls_ca.crt;

        location / {
            default_type 'text/plain';

            content_by_lua_block {
                ngx.say("simple logging return")
            }

            more_clear_headers Date;
        }
    }
--- config
    location /t {
        proxy_pass                    https://unix:$TEST_NGINX_HTML_DIR/nginx.sock;
        proxy_ssl_protocols           TLSv1.2;
        proxy_ssl_verify              on;
        proxy_ssl_name                example.com;
        proxy_ssl_certificate         ../../cert/mtls_client.crt;
        proxy_ssl_certificate_key     ../../cert/mtls_client.key;
        proxy_ssl_trusted_certificate ../../cert/mtls_ca.crt;
        proxy_ssl_session_reuse       off;

        proxy_ssl_certificate_by_lua_block {
            local proxy_ssl = require "ngx.proxyssl"

            -- get_tls1_version_str will call get_tls1_version
            local ver, err = proxy_ssl.get_tls1_version_str()
            if not ver then
                ngx.log(ngx.ERR, "failed to get TLS1 version: ", err)
                return
            end
            ngx.log(ngx.INFO, "got TLS1 version: ", ver)
        }
    }
--- request
GET /t
--- error_code: 200
--- response_body
simple logging return
--- error_log
got TLS1 version: TLSv1.2
--- no_error_log
[error]
[alert]
