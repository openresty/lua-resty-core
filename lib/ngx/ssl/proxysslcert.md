Name
====

ngx.ssl.proxysslcert - Lua API for post-processing SSL server certificate request message and setting proxy ssl certificate and its related private key and chain for NGINX upstream SSL connections.

Table of Contents
=================

* [Name](#name)
* [Status](#status)
* [Synopsis](#synopsis)
* [Description](#description)
* [Methods](#methods)
    * [clear_certs](#clear_certs)
    * [set_der_cert](#set_der_cert)
    * [set_der_priv_key](#set_der_priv_key)
    * [set_cert](#set_cert)
    * [set_priv_key](#set_priv_key)
* [Community](#community)
    * [English Mailing List](#english-mailing-list)
    * [Chinese Mailing List](#chinese-mailing-list)
* [Bugs and Patches](#bugs-and-patches)
* [Author](#author)
* [Copyright and License](#copyright-and-license)
* [See Also](#see-also)

Status
======

This Lua module is production ready.

Synopsis
========

```nginx
# nginx.conf

server {
    listen 443 ssl;
    server_name   test.com;
    ssl_certificate /path/to/cert.crt;
    ssl_certificate_key /path/to/key.key;

    location /t {
        proxy_ssl_certificate /path/to/cert.crt;
        proxy_ssl_certificate_key /path/to/key.key;
        proxy_pass https://upstream;

        proxy_ssl_certificate_by_lua_block {
            local ssl = require "ngx.ssl"
            local proxy_ssl_cert = require "ngx.ssl.proxysslcert"

            -- NOTE: for illustration only, we don't handle error below

            local f = assert(io.open("/path/to/cert.crt"))
            local cert_data = f:read("*a")
            f:close()

            local cert, err = ssl.parse_pem_cert(cert_data)
            local ok, err = proxy_ssl_cert.set_cert(cert)

            local f = assert(io.open("/path/to/key.key"))
            local pkey_data = f:read("*a")
            f:close()

            local pkey, err = ssl.parse_pem_priv_key(pkey_data)
            local ok, err = proxy_ssl_cert.set_priv_key(pkey)
            -- ...
        }
    }
    ...
 }
```

Description
===========

This Lua module provides API functions for post-processing SSL server certificate request message and setting proxy ssl certificate and its related private key and chain for NGINX upstream SSL connections.

It must to be used in the context [proxy_ssl_certificate_by_lua*](https://github.com/openresty/lua-nginx-module/#proxy_ssl_certificate_by_lua_block).

This directive runs user Lua code when Nginx is about to post-process the SSL server certificate request message from upstream.

It is particularly useful for setting the SSL certificate chain and the corresponding private key for the         upstream SSL (https) connections.

To load the `ngx.ssl.proxysslcert` module in Lua, just write

```lua
local proxy_ssl_cert = require "ngx.ssl.proxysslcert"
```

[Back to TOC](#table-of-contents)

Methods
=======

clear_certs
-----------
**syntax:** *ok, err = proxy_ssl_cert.clear_certs()*

**context:** *proxy_ssl_certificate_by_lua&#42;*

It's the same as [ngx.ssl.clear_certs](https://github.com/openresty/lua-resty-core/blob/master/lib/ngx/ssl.md#clear_certs), but for the current upstream SSL connection.

This function can only be called in the context of [proxy_ssl_certificate_by_lua*](https://github.com/openresty/lua-nginx-module/#proxy_ssl_certificate_by_lua_block).

[Back to TOC](#table-of-contents)

set_der_cert
------------
**syntax:** *ok, err = proxy_ssl_cert.set_der_cert(der_cert_chain)*

**context:** *proxy_ssl_certificate_by_lua&#42;*

It's the same as [ngx.ssl.set_der_cert](https://github.com/openresty/lua-resty-core/blob/master/lib/ngx/ssl.md#set_der_cert), but for the current upstream SSL connection.

This function can only be called in the context of [proxy_ssl_certificate_by_lua*](https://github.com/openresty/lua-nginx-module/#proxy_ssl_certificate_by_lua_block).

[Back to TOC](#table-of-contents)

set_der_priv_key
----------------
**syntax:** *ok, err = proxy_ssl_cert.set_der_priv_key(der_priv_key)*

**context:** *proxy_ssl_certificate_by_lua&#42;*

It's the same as [ngx.ssl.set_der_priv_key](https://github.com/openresty/lua-resty-core/blob/master/lib/ngx/ssl.md#set_der_priv_key), but for the current upstream SSL connection.

This function can only be called in the context of [proxy_ssl_certificate_by_lua*](https://github.com/openresty/lua-nginx-module/#proxy_ssl_certificate_by_lua_block).

[Back to TOC](#table-of-contents)

set_cert
--------
**syntax:** *ok, err = proxy_ssl_cert.set_cert(cert_chain)*

**context:** *proxy_ssl_certificate_by_lua&#42;*

It's the same as [ngx.ssl.set_cert](https://github.com/openresty/lua-resty-core/blob/master/lib/ngx/ssl.md#set_cert), but for the current upstream SSL connection.

This function can only be called in the context of [proxy_ssl_certificate_by_lua*](https://github.com/openresty/lua-nginx-module/#proxy_ssl_certificate_by_lua_block).

[Back to TOC](#table-of-contents)

set_priv_key
------------
**syntax:** *ok, err = proxy_ssl_cert.set_priv_key(priv_key)*

**context:** *proxy_ssl_certificate_by_lua&#42;*

It's the same as [ngx.ssl.set_priv_key](https://github.com/openresty/lua-resty-core/blob/master/lib/ngx/ssl.md#set_priv_key), but for the current upstream SSL connection.

This function can only be called in the context of [proxy_ssl_certificate_by_lua*](https://github.com/openresty/lua-nginx-module/#proxy_ssl_certificate_by_lua_block).

[Back to TOC](#table-of-contents)

Community
=========

[Back to TOC](#table-of-contents)

English Mailing List
--------------------

The [openresty-en](https://groups.google.com/group/openresty-en) mailing list is for English speakers.

[Back to TOC](#table-of-contents)

Chinese Mailing List
--------------------

The [openresty](https://groups.google.com/group/openresty) mailing list is for Chinese speakers.

[Back to TOC](#table-of-contents)

Bugs and Patches
================

Please report bugs or submit patches by

1. creating a ticket on the [GitHub Issue Tracker](https://github.com/openresty/lua-resty-core/issues),
1. or posting to the [OpenResty community](#community).

[Back to TOC](#table-of-contents)

Author
======

Fuhong Ma &lt;willmafh@hotmail.com&gt; (willmafh)

[Back to TOC](#table-of-contents)

Copyright and License
=====================

This module is licensed under the BSD license.

Copyright (C) 2016-2017, by Yichun "agentzh" Zhang, OpenResty Inc.

All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

[Back to TOC](#table-of-contents)

See AlsoCopyright
========
* the ngx_lua module: https://github.com/openresty/lua-nginx-module
* the [proxy_ssl_certificate_by_lua*](https://github.com/openresty/lua-nginx-module/#proxy_ssl_certificate_by_lua_block) directive.
* the [lua-resty-core](https://github.com/openresty/lua-resty-core) library.
* OpenResty: https://openresty.org

[Back to TOC](#table-of-contents)
