Name
====

ngx.proxyssl - Lua API for controlling NGINX upstream SSL handshakes

Table of Contents
=================

* [Name](#name)
* [Status](#status)
* [Synopsis](#synopsis)
* [Description](#description)
* [Methods](#methods)
    * [get_tls1_version](#get_tls1_version)
    * [get_tls1_version_str](#get_tls1_version_str)
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
server {
    listen 443 ssl;
    server_name   test.com;

    proxy_ssl_certificate_by_lua_block {
        local proxy_ssl = require "ngx.proxyssl"

        local ver, err = proxy_ssl.get_tls1_version_str()
        if not ver then
            ngx.log(ngx.ERR, "failed to get TLS1 version: ", err)
            return
        end
        ngx.log(ngx.INFO, "got TLS1 version: ", ver)
    }

    location / {
        root html;
    }
}
```

Description
===========

This Lua module provides API functions to control the SSL handshake process in contexts like [proxy_ssl_certificate_by_lua*](https://github.com/openresty/lua-nginx-module/#proxy_ssl_certificate_by_lua_block) and [proxy_ssl_verify_by_lua*](https://github.com/openresty/lua-nginx-module/#proxy_ssl_verify_by_lua_block) (of the [ngx_lua](https://github.com/openresty/lua-nginx-module#readme) module).

This Lua module only provides API functions that can be used in any upstream SSL context, so here we make it an independent module.

To load the `ngx.proxyssl` module in Lua, just write

```lua
local proxy_ssl = require "ngx.proxyssl"
```

[Back to TOC](#table-of-contents)

Methods
=======

get_tls1_version
----------------
**syntax:** *ver, err = proxy_ssl.get_tls1_version()*

**context:** *any*

It's the same as [ngx.ssl.get_tls1_version](https://github.com/openresty/lua-resty-core/blob/master/lib/ngx/ssl.md#get_tls1_version), but for the current upstream SSL connection.

This function can be called in any context where upstream https is used.

[Back to TOC](#table-of-contents)

get_tls1_version_str
--------------------
**syntax:** *ver, err = proxy_ssl.get_tls1_version_str()*

**context:** *any*

It's the same as [ngx.ssl.get_tls1_version_str](https://github.com/openresty/lua-resty-core/blob/master/lib/ngx/ssl.md#get_tls1_version_str), but for the current upstream SSL connection.

This function can be called in any context where upstream https is used.

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
2. or posting to the [OpenResty community](#community).

[Back to TOC](#table-of-contents)

Author
======

Fuhong Ma &lt;willmafh@hotmail.com&gt; (willmafh)

[Back to TOC](#table-of-contents)

Copyright and License
=====================

This module is licensed under the BSD license.

Copyright (C) 2015-2017, by Yichun "agentzh" Zhang, OpenResty Inc.

All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

[Back to TOC](#table-of-contents)

See Also
========
* the ngx_lua module: https://github.com/openresty/lua-nginx-module
* the [proxy_ssl_certificate_by_lua*](https://github.com/openresty/lua-nginx-module/#proxy_ssl_certificate_by_lua_block) directive.
* the [proxy_ssl_verify_by_lua*](https://github.com/openresty/lua-nginx-module/#proxy_ssl_verify_by_lua_block) directive.
* the [lua-resty-core](https://github.com/openresty/lua-resty-core) library.
* OpenResty: https://openresty.org

[Back to TOC](#table-of-contents)
