# vim:set ft=perl ts=4 sw=4 et fdm=marker:
use lib '.';
use t::TestCore;

repeat_each(2);

my $NginxBinary = $ENV{TEST_NGINX_BINARY} || 'nginx';
my $version = `$NginxBinary -V 2>&1`;
if ($version =~ /built with OpenSSL (0\S*|1\.0\S*|1\.1\.0\S*)/) {
    plan(skip_all => "OpenSSL 1.1.1 or later required");
} elsif ($version =~ /\bBoringSSL\b/) {
    plan(skip_all => "OpenSSL client hello callback required");
} else {
    plan tests => repeat_each() * blocks() * 5;
}

no_long_string();
$ENV{TEST_NGINX_LUA_PACKAGE_PATH} = $t::TestCore::lua_package_path;
$ENV{TEST_NGINX_HTML_DIR} ||= html_dir();

add_block_preprocessor(sub {
    my $block = shift;
    my $tls = $block->tls || 'TLSv1.2';
    my $hello = $block->client_hello || '';
    my $before = $block->before_handshake || '';
    my $init = $block->init_script || '';
    my $failure = $block->handshake_failure || '';
    $block->set_value('http_config', <<_EOC_);
    lua_package_path "\$TEST_NGINX_LUA_PACKAGE_PATH";
    $init
    server {
        listen unix:\$TEST_NGINX_HTML_DIR/nginx.sock ssl;
        ssl_certificate ../../cert/test.crt;
        ssl_certificate_key ../../cert/test.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256;
        ssl_conf_command Ciphersuites TLS_AES_256_GCM_SHA384;
        ssl_prefer_server_ciphers on;
        ssl_client_hello_by_lua_block {
            local clt = require "ngx.ssl.clienthello"
            $hello
        }
        location / { content_by_lua_block { ngx.say(ngx.var.ssl_cipher) } }
    }
_EOC_
    $block->set_value('config', <<_EOC_);
    lua_ssl_protocols $tls;
    lua_ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    location /t {
        content_by_lua_block {
            $before
            local sock = ngx.socket.tcp()
            sock:settimeout(3000)
            local ok, err = sock:connect("unix:\$TEST_NGINX_HTML_DIR/nginx.sock")
            assert(ok, err)
            ok, err = sock:sslhandshake(false, "test.com", false)
            if "$failure" ~= "" then
                assert(ok == nil, "TLSv1.3 should be disabled")
                assert(err == "handshake failed", err)
                ngx.say(err)
                return
            end
            assert(ok, err)
            local crlf = string.char(13, 10)
            local bytes, err = sock:send("GET / HTTP/1.0" .. crlf
                                         .. "Host: test.com" .. crlf .. crlf)
            assert(bytes, err)
            while true do
                local line, err = sock:receive()
                assert(line, err)
                if line == "" then
                    break
                end
            end
            local cipher, err = sock:receive()
            assert(cipher, err)
            ngx.say(cipher)
            sock:close()
        }
    }
_EOC_
});

run_tests();

__DATA__


=== TEST 1: set TLSv1.2 cipher list
--- tls: TLSv1.2
--- client_hello
assert(clt.set_ciphers("ECDHE-RSA-AES256-GCM-SHA384", true))
--- request
GET /t
--- response_body
ECDHE-RSA-AES256-GCM-SHA384
--- no_error_log
[error]
[alert]
[emerg]


=== TEST 2: set TLSv1.3 ciphersuites
--- tls: TLSv1.3
--- client_hello
assert(clt.set_ciphersuites("TLS_AES_128_GCM_SHA256", true))
--- request
GET /t
--- response_body
TLS_AES_128_GCM_SHA256
--- no_error_log
[error]
[alert]
[emerg]


=== TEST 3: cipher list leaves TLSv1.3 unchanged
--- tls: TLSv1.3
--- client_hello
assert(clt.set_ciphers("ECDHE-RSA-AES256-GCM-SHA384", true))
--- request
GET /t
--- response_body
TLS_AES_256_GCM_SHA384
--- no_error_log
[error]
[alert]
[emerg]


=== TEST 4: ciphersuites leave TLSv1.2 unchanged
--- tls: TLSv1.2
--- client_hello
assert(clt.set_ciphersuites("TLS_AES_128_GCM_SHA256", true))
--- request
GET /t
--- response_body
ECDHE-RSA-AES128-GCM-SHA256
--- no_error_log
[error]
[alert]
[emerg]


=== TEST 5: server cipher preference
--- tls: TLSv1.2
--- client_hello
assert(clt.set_ciphers("ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256", true))
--- request
GET /t
--- response_body
ECDHE-RSA-AES256-GCM-SHA384
--- no_error_log
[error]
[alert]
[emerg]


=== TEST 6: client cipher preference
--- tls: TLSv1.2
--- client_hello
assert(clt.set_ciphers("ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256", false))
--- request
GET /t
--- response_body
ECDHE-RSA-AES128-GCM-SHA256
--- no_error_log
[error]
[alert]
[emerg]


=== TEST 7: omitted preference uses client order
--- tls: TLSv1.2
--- client_hello
assert(clt.set_ciphers("ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256"))
--- request
GET /t
--- response_body
ECDHE-RSA-AES128-GCM-SHA256
--- no_error_log
[error]
[alert]
[emerg]


=== TEST 8: cipher preference can be cleared
--- tls: TLSv1.2
--- client_hello
assert(clt.set_ciphers("ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256", true))
assert(clt.set_ciphers("ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256", false))
--- request
GET /t
--- response_body
ECDHE-RSA-AES128-GCM-SHA256
--- no_error_log
[error]
[alert]
[emerg]


=== TEST 9: ciphersuite setter enables server preference
--- tls: TLSv1.2
--- client_hello
assert(clt.set_ciphers("ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256", false))
assert(clt.set_ciphersuites("TLS_AES_128_GCM_SHA256", true))
--- request
GET /t
--- response_body
ECDHE-RSA-AES256-GCM-SHA384
--- no_error_log
[error]
[alert]
[emerg]


=== TEST 10: ciphersuite setter clears server preference
--- tls: TLSv1.2
--- client_hello
assert(clt.set_ciphers("ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256", true))
assert(clt.set_ciphersuites("TLS_AES_128_GCM_SHA256", false))
--- request
GET /t
--- response_body
ECDHE-RSA-AES128-GCM-SHA256
--- no_error_log
[error]
[alert]
[emerg]


=== TEST 11: invalid cipher list preserves defaults
--- tls: TLSv1.2
--- client_hello
local ok, err = clt.set_ciphers("NOT-A-CIPHER", true)
assert(ok == nil)
assert(err == "failed to set ciphers", err)
--- request
GET /t
--- response_body
ECDHE-RSA-AES128-GCM-SHA256
--- no_error_log
[error]
[alert]
[emerg]


=== TEST 12: invalid ciphersuites preserve defaults
--- tls: TLSv1.3
--- client_hello
local ok, err = clt.set_ciphersuites("TLS_NOT_A_SUITE", true)
assert(ok == nil)
assert(err == "failed to set ciphersuites", err)
--- request
GET /t
--- response_body
TLS_AES_256_GCM_SHA384
--- no_error_log
[error]
[alert]
[emerg]


=== TEST 13: invalid cipher list preserves earlier settings and preference
--- tls: TLSv1.2
--- client_hello
assert(clt.set_ciphers("ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256", false))
local ok, err = clt.set_ciphers("NOT-A-CIPHER", true)
assert(ok == nil)
assert(err == "failed to set ciphers", err)
--- request
GET /t
--- response_body
ECDHE-RSA-AES128-GCM-SHA256
--- no_error_log
[error]
[alert]
[emerg]


=== TEST 14: invalid ciphersuites preserve earlier settings
--- tls: TLSv1.3
--- client_hello
assert(clt.set_ciphersuites("TLS_AES_128_GCM_SHA256", true))
local ok, err = clt.set_ciphersuites("TLS_NOT_A_SUITE", false)
assert(ok == nil)
assert(err == "failed to set ciphersuites", err)
--- request
GET /t
--- response_body
TLS_AES_128_GCM_SHA256
--- no_error_log
[error]
[alert]
[emerg]


=== TEST 15: invalid ciphersuites preserve cipher preference
--- tls: TLSv1.2
--- client_hello
assert(clt.set_ciphers("ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256", false))
local ok, err = clt.set_ciphersuites("TLS_NOT_A_SUITE", true)
assert(ok == nil)
assert(err == "failed to set ciphersuites", err)
--- request
GET /t
--- response_body
ECDHE-RSA-AES128-GCM-SHA256
--- no_error_log
[error]
[alert]
[emerg]


=== TEST 16: partially invalid cipher list applies valid subset
--- tls: TLSv1.2
--- client_hello
assert(clt.set_ciphers("TRASH:ECDHE-RSA-AES256-GCM-SHA384:GARBAGE", true))
--- request
GET /t
--- response_body
ECDHE-RSA-AES256-GCM-SHA384
--- no_error_log
[error]
[alert]
[emerg]


=== TEST 17: partially invalid ciphersuites apply valid subset
--- tls: TLSv1.3
--- client_hello
assert(clt.set_ciphersuites("TRASH:TLS_AES_128_GCM_SHA256:GARBAGE", true))
--- request
GET /t
--- response_body
TLS_AES_128_GCM_SHA256
--- no_error_log
[error]
[alert]
[emerg]


=== TEST 18: empty cipher list is rejected without aborting handshake
--- tls: TLSv1.2
--- client_hello
local ok, err = clt.set_ciphers("", true)
assert(ok == nil)
assert(err == "failed to set ciphers", err)
--- request
GET /t
--- response_body
ECDHE-RSA-AES128-GCM-SHA256
--- no_error_log
[error]
[alert]
[emerg]


=== TEST 19: empty ciphersuites disable TLSv1.3
--- tls: TLSv1.3
--- client_hello
assert(clt.set_ciphersuites("", true))
--- handshake_failure: yes
--- request
GET /t
--- response_body
handshake failed
--- no_error_log
[alert]
[emerg]
lua entry thread aborted


=== TEST 20: empty ciphersuites leave TLSv1.2 available
--- tls: TLSv1.2
--- client_hello
assert(clt.set_ciphersuites("", true))
--- request
GET /t
--- response_body
ECDHE-RSA-AES128-GCM-SHA256
--- no_error_log
[error]
[alert]
[emerg]


=== TEST 21: valid settings can follow rejection
--- tls: TLSv1.2
--- client_hello
local ok, err = clt.set_ciphers("NOT-A-CIPHER", true)
assert(ok == nil)
assert(err == "failed to set ciphers", err)
assert(clt.set_ciphers("ECDHE-RSA-AES256-GCM-SHA384", true))
ok, err = clt.set_ciphersuites("TLS_NOT_A_SUITE", true)
assert(ok == nil)
assert(err == "failed to set ciphersuites", err)
assert(clt.set_ciphersuites("TLS_AES_128_GCM_SHA256", true))
--- request
GET /t
--- response_body
ECDHE-RSA-AES256-GCM-SHA384
--- no_error_log
[error]
[alert]
[emerg]


=== TEST 22: cipher arguments must be strings
--- tls: TLSv1.2
--- client_hello
for _, value in ipairs({false, 123, {}}) do
    local ok, err = pcall(clt.set_ciphers, value, true)
    assert(ok == false)
    assert(err == "ciphers must be a string", err)
    ok, err = pcall(clt.set_ciphersuites, value, true)
    assert(ok == false)
    assert(err == "ciphersuites must be a string", err)
end
local ok, err = pcall(clt.set_ciphers, nil)
assert(ok == false)
assert(err == "ciphers must be a string", err)
ok, err = pcall(clt.set_ciphersuites, nil)
assert(ok == false)
assert(err == "ciphersuites must be a string", err)
--- request
GET /t
--- response_body
ECDHE-RSA-AES128-GCM-SHA256
--- no_error_log
[error]
[alert]
[emerg]


=== TEST 23: setters require a request
--- tls: TLSv1.2
--- init_script
init_by_lua_block {
    local clt = require "ngx.ssl.clienthello"
    local ok, err = pcall(clt.set_ciphers, "DEFAULT", true)
    assert(ok == false)
    assert(err == "no request found", err)
    ok, err = pcall(clt.set_ciphersuites, "TLS_AES_128_GCM_SHA256", true)
    assert(ok == false)
    assert(err == "no request found", err)
}
--- request
GET /t
--- response_body
ECDHE-RSA-AES128-GCM-SHA256
--- no_error_log
[error]
[alert]
[emerg]


=== TEST 24: setters are disabled after the client hello
--- tls: TLSv1.2
--- before_handshake
local clt = require "ngx.ssl.clienthello"
local ok, err = pcall(clt.set_ciphers, "DEFAULT", true)
assert(ok == false)
assert(err == "API disabled in the current context", err)
ok, err = pcall(clt.set_ciphersuites, "TLS_AES_128_GCM_SHA256", true)
assert(ok == false)
assert(err == "API disabled in the current context", err)
--- request
GET /t
--- response_body
ECDHE-RSA-AES128-GCM-SHA256
--- no_error_log
[error]
[alert]
[emerg]


=== TEST 25: rejection preserves queued OpenSSL errors
--- tls: TLSv1.2
--- client_hello
local ffi = require "ffi"
ffi.cdef[[
    void *TLS_method(void);
    void *SSL_CTX_new(const void *method);
    void SSL_CTX_free(void *ctx);
    int SSL_CTX_set_cipher_list(void *ctx, const char *ciphers);
    unsigned long ERR_peek_error(void);
    unsigned long ERR_peek_last_error(void);
    void ERR_clear_error(void);
]]
local C = ffi.C
local ctx = C.SSL_CTX_new(C.TLS_method())
assert(ctx ~= nil)
assert(C.SSL_CTX_set_cipher_list(ctx, "NOT-A-CIPHER") == 0)
C.SSL_CTX_free(ctx)
local first = C.ERR_peek_error()
local last = C.ERR_peek_last_error()
assert(first ~= 0)
local ok, err = clt.set_ciphers("NOT-A-CIPHER", true)
assert(ok == nil)
assert(err == "failed to set ciphers", err)
ok, err = clt.set_ciphersuites("TLS_NOT_A_SUITE", true)
assert(ok == nil)
assert(err == "failed to set ciphersuites", err)
local same = first == C.ERR_peek_error()
             and last == C.ERR_peek_last_error()
C.ERR_clear_error()
assert(same, "OpenSSL error queue changed")
--- request
GET /t
--- response_body
ECDHE-RSA-AES128-GCM-SHA256
--- no_error_log
[error]
[alert]
[emerg]


=== TEST 26: success preserves queued OpenSSL errors
--- tls: TLSv1.2
--- client_hello
local ffi = require "ffi"
ffi.cdef[[
    void *TLS_method(void);
    void *SSL_CTX_new(const void *method);
    void SSL_CTX_free(void *ctx);
    int SSL_CTX_set_cipher_list(void *ctx, const char *ciphers);
    unsigned long ERR_peek_error(void);
    unsigned long ERR_peek_last_error(void);
    void ERR_clear_error(void);
]]
local C = ffi.C
local ctx = C.SSL_CTX_new(C.TLS_method())
assert(ctx ~= nil)
assert(C.SSL_CTX_set_cipher_list(ctx, "NOT-A-CIPHER") == 0)
C.SSL_CTX_free(ctx)
local first = C.ERR_peek_error()
local last = C.ERR_peek_last_error()
assert(first ~= 0)
assert(clt.set_ciphers("ECDHE-RSA-AES256-GCM-SHA384", true))
assert(clt.set_ciphersuites("TLS_AES_128_GCM_SHA256", true))
local same = first == C.ERR_peek_error()
             and last == C.ERR_peek_last_error()
C.ERR_clear_error()
assert(same, "OpenSSL error queue changed")
--- request
GET /t
--- response_body
ECDHE-RSA-AES256-GCM-SHA384
--- no_error_log
[error]
[alert]
[emerg]
