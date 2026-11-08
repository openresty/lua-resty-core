# vim:set ft= ts=4 sw=4 et fdm=marker:

use lib '.';
use t::TestCore::Stream;

repeat_each(2);

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
$ENV{TEST_NGINX_LUA_PACKAGE_PATH} = "$t::TestCore::Stream::lua_package_path";
$ENV{TEST_NGINX_HTML_DIR} ||= html_dir();

sub read_file {
    my $infile = shift;
    open my $in, $infile
        or die "cannot open $infile for reading: $!";
    my $cert = do { local $/; <$in> };
    close $in;
    $cert;
}

our $MTLSServerCert = read_file("t/cert/mtls_server.crt");
our $MTLSServerKey  = read_file("t/cert/mtls_server.key");
our $MTLSCA         = read_file("t/cert/mtls_ca.crt");
our $UnrelatedCA    = read_file("t/cert/test.crt");

our $StreamConfigWithHelpers = <<_EOC_;
    lua_package_path '$t::TestCore::Stream::lua_package_path';

    init_by_lua_block {
        $t::TestCore::Stream::init_by_lua_block

        local ffi = require "ffi"
        ffi.cdef[[
            typedef struct x509_store_st X509_STORE;
            typedef struct x509_st X509;
            typedef struct bio_st BIO;
            typedef struct bio_method_st BIO_METHOD;

            X509_STORE *X509_STORE_new(void);
            int X509_STORE_add_cert(X509_STORE *ctx, X509 *x);
            void X509_STORE_free(X509_STORE *v);

            BIO_METHOD *BIO_s_mem(void);
            BIO *BIO_new(BIO_METHOD *type);
            int BIO_write(BIO *b, const void *buf, int len);
            void BIO_free(BIO *a);
            X509 *PEM_read_bio_X509(BIO *bp, X509 **x, void *cb, void *u);
            void X509_free(X509 *a);
        ]]

        function _G.load_store_from_pem(pem)
            local C = ffi.C
            local bio = C.BIO_new(C.BIO_s_mem())
            if bio == nil then return nil, "BIO_new failed" end
            if C.BIO_write(bio, pem, #pem) <= 0 then
                C.BIO_free(bio)
                return nil, "BIO_write failed"
            end
            local x509 = C.PEM_read_bio_X509(bio, nil, nil, nil)
            C.BIO_free(bio)
            if x509 == nil then return nil, "PEM_read_bio_X509 failed" end
            local store = C.X509_STORE_new()
            if store == nil then
                C.X509_free(x509)
                return nil, "X509_STORE_new failed"
            end
            if C.X509_STORE_add_cert(store, x509) ~= 1 then
                C.X509_free(x509)
                C.X509_STORE_free(store)
                return nil, "X509_STORE_add_cert failed"
            end
            C.X509_free(x509)
            return ffi.gc(store, C.X509_STORE_free)
        end
    }
_EOC_

run_tests();

__DATA__

=== TEST 1: handshake succeeds with a custom X509 trusted store
--- stream_config eval
"$::StreamConfigWithHelpers

server {
    listen unix:$ENV{TEST_NGINX_HTML_DIR}/tls.sock ssl;
    ssl_certificate ../../cert/mtls_server.crt;
    ssl_certificate_key ../../cert/mtls_server.key;

    return 'it works!\n';
}
"
--- stream_server_config
    lua_ssl_verify_depth 2;

    content_by_lua_block {
        local f = assert(io.open("t/cert/mtls_ca.crt", "r"))
        local pem = f:read("*a")
        f:close()

        local store, err = load_store_from_pem(pem)
        if not store then
            ngx.say("failed to load store: ", err)
            return
        end

        local sock = ngx.socket.tcp()
        sock:settimeout(3000)

        local ok, err = sock:connect("unix:$TEST_NGINX_HTML_DIR/tls.sock")
        if not ok then
            ngx.say("failed to connect: ", err)
            return
        end

        local ok, err = sock:settrustedstore(store)
        if not ok then
            ngx.say("failed to settrustedstore: ", err)
            return
        end

        local sess, err = sock:sslhandshake(nil, "example.com", true)
        if not sess then
            ngx.say("failed to do SSL handshake: ", err)
            return
        end

        ngx.say("ssl handshake: ", type(sess))

        while true do
            local line, err = sock:receive()
            if not line then
                break
            end

            ngx.say("received: ", line)
        end

        sock:close()
    }
--- stream_response
ssl handshake: userdata
received: it works!
--- no_error_log
[error]
[alert]
[crit]



=== TEST 2: handshake fails without a trusted store and without lua_ssl_trusted_certificate
--- stream_config eval
"$::StreamConfigWithHelpers

server {
    listen unix:$ENV{TEST_NGINX_HTML_DIR}/tls.sock ssl;
    ssl_certificate ../../cert/mtls_server.crt;
    ssl_certificate_key ../../cert/mtls_server.key;

    return 'it works!\n';
}
"
--- stream_server_config
    content_by_lua_block {
        local sock = ngx.socket.tcp()
        sock:settimeout(3000)

        local ok, err = sock:connect("unix:$TEST_NGINX_HTML_DIR/tls.sock")
        if not ok then
            ngx.say("failed to connect: ", err)
            return
        end

        local sess, err = sock:sslhandshake(nil, "example.com", true)
        if not sess then
            ngx.say("failed to do SSL handshake: ", err)
            return
        end

        ngx.say("unexpected success")
        sock:close()
    }
--- stream_response_like
^failed to do SSL handshake: .+
--- error_log
lua ssl certificate verify error
--- no_error_log
[alert]
[crit]



=== TEST 3: handshake fails with a trusted store that has the wrong CA
--- stream_config eval
"$::StreamConfigWithHelpers

server {
    listen unix:$ENV{TEST_NGINX_HTML_DIR}/tls.sock ssl;
    ssl_certificate ../../cert/mtls_server.crt;
    ssl_certificate_key ../../cert/mtls_server.key;

    return 'it works!\n';
}
"
--- stream_server_config
    content_by_lua_block {
        local f = assert(io.open("t/cert/test.crt", "r"))
        local pem = f:read("*a")
        f:close()

        local store, err = load_store_from_pem(pem)
        if not store then
            ngx.say("failed to load store: ", err)
            return
        end

        local sock = ngx.socket.tcp()
        sock:settimeout(3000)
        assert(sock:connect("unix:$TEST_NGINX_HTML_DIR/tls.sock"))

        local ok, err = sock:settrustedstore(store)
        if not ok then
            ngx.say("failed to settrustedstore: ", err)
            return
        end

        local sess, err = sock:sslhandshake(nil, "example.com", true)
        if sess then
            ngx.say("unexpected success")
        else
            ngx.say("handshake failed: ", err)
        end

        sock:close()
    }
--- stream_response_like
handshake failed: .*: unable to get local issuer certificate
--- error_log
lua ssl certificate verify error
--- no_error_log
[alert]
[crit]



=== TEST 4: settrustedstore returns "closed" after the socket has been closed
--- stream_config eval
"$::StreamConfigWithHelpers

server {
    listen unix:$ENV{TEST_NGINX_HTML_DIR}/tls.sock ssl;
    ssl_certificate ../../cert/mtls_server.crt;
    ssl_certificate_key ../../cert/mtls_server.key;

    return 'it works!\n';
}
"
--- stream_server_config
    content_by_lua_block {
        local f = assert(io.open("t/cert/mtls_ca.crt", "r"))
        local pem = f:read("*a")
        f:close()

        local store = assert(load_store_from_pem(pem))

        local sock = ngx.socket.tcp()
        sock:settimeout(3000)
        assert(sock:connect("unix:$TEST_NGINX_HTML_DIR/tls.sock"))
        assert(sock:close())

        local ok, err = sock:settrustedstore(store)
        ngx.say("settrustedstore: ", ok, " ", err)
    }
--- stream_response
settrustedstore: nil closed
--- no_error_log
[error]
[alert]
[crit]



=== TEST 5: passing nil clears the trusted store
--- stream_config eval
"$::StreamConfigWithHelpers

server {
    listen unix:$ENV{TEST_NGINX_HTML_DIR}/tls.sock ssl;
    ssl_certificate ../../cert/mtls_server.crt;
    ssl_certificate_key ../../cert/mtls_server.key;

    return 'it works!\n';
}
"
--- stream_server_config
    lua_ssl_trusted_certificate ../../cert/mtls_ca.crt;
    lua_ssl_verify_depth 2;

    content_by_lua_block {
        -- First set a wrong CA, then clear it. The handshake should
        -- then succeed via lua_ssl_trusted_certificate, proving the
        -- C-side slot was cleared (not just the lua-side ref).
        local f = assert(io.open("t/cert/test.crt", "r"))
        local wrong_pem = f:read("*a")
        f:close()

        local wrong_store = assert(load_store_from_pem(wrong_pem))

        local sock = ngx.socket.tcp()
        sock:settimeout(3000)
        assert(sock:connect("unix:$TEST_NGINX_HTML_DIR/tls.sock"))

        assert(sock:settrustedstore(wrong_store))
        assert(sock:settrustedstore(nil))

        local sess, err = sock:sslhandshake(nil, "example.com", true)
        if not sess then
            ngx.say("handshake failed: ", err)
            return
        end

        ngx.say("handshake ok")
        sock:close()
    }
--- stream_response
handshake ok
--- no_error_log
[error]
[alert]
[crit]



=== TEST 6: bad arg type is rejected before any FFI / network work
--- stream_config eval
"$::StreamConfigWithHelpers

server {
    listen unix:$ENV{TEST_NGINX_HTML_DIR}/tls.sock ssl;
    ssl_certificate ../../cert/mtls_server.crt;
    ssl_certificate_key ../../cert/mtls_server.key;

    return 'it works!\n';
}
"
--- stream_server_config
    content_by_lua_block {
        local sock = ngx.socket.tcp()
        sock:settimeout(3000)
        assert(sock:connect("unix:$TEST_NGINX_HTML_DIR/tls.sock"))

        local ok, err = sock:settrustedstore("not cdata")
        ngx.say("settrustedstore: ", ok, " ", err)

        sock:close()
    }
--- stream_response
settrustedstore: nil bad store arg: cdata expected, got string
--- no_error_log
[error]
[alert]
[crit]
