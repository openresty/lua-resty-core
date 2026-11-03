Name
====

`ngx.resolver` - Lua API for Nginx core's dynamic resolver.

Table of Contents
=================

* [Name](#name)
* [Status](#status)
* [Synopsis](#synopsis)
* [Methods](#methods)
    * [resolve](#resolve)
* [Community](#community)
    * [English Mailing List](#english-mailing-list)
    * [Chinese Mailing List](#chinese-mailing-list)
* [Bugs and Patches](#bugs-and-patches)
* [Author](#author)
* [Copyright and License](#copyright-and-license)
* [See Also](#see-also)

Status
======

TBD

Synopsis
========

```nginx
 http {
     resolver 8.8.8.8;

     upstream backend {
         server 0.0.0.0;

         balancer_by_lua_block {
             local balancer = require 'ngx.balancer'
             
             local ctx = ngx.ctx
             local ok, err = balancer.set_current_peer(ctx.peer_addr, ctx.peer_port)
             if not ok then
                 ngx.log(ngx.ERR, "failed to set the peer: ", err)
                 ngx.exit(500)
             end
         }
     }

     server {
         listen 8080;

         access_by_lua_block {
             local resolver = require 'ngx.resolver'
             
             local ctx = ngx.ctx
             local addr, err = resolver.resolve('google.com', true, false)
             if addr then
                 ctx.peer_addr = addr
                 ctx.peer_port = 80
             end
         }

         location / {
             proxy_pass http://backend;
         }
     }
 }
```

[Back to TOC](#table-of-contents)

Method
=======

resolve
-----------------
**syntax:** *address,err = resolver.resolve(hostname, ipv4, ipv6)*

**context:** *rewrite_by_lua&#42;, access_by_lua&#42;, content_by_lua&#42;, ngx.timer.&#42;, ssl_certificate_by_lua&#42;, ssl_session_fetch_by_lua&#42;*

Resolve `hostname` into IP address by using Nginx core's dynamic resolver. Returns IP address string. In case of error, `nil` will be returned as well as a string describing the error.

The `ipv4` and `ipv6`argument are boolean flags that controls whether A or AAAA DNS records we are interested in.
Please, note that resolver has its own configuration option `ipv6=on|off`, which has higher precedence over above flags.
The 'ipv4' flag has default value `true`.

It is required to configure the [resolver](http://nginx.org/en/docs/http/ngx_http_core_module.html#resolver) directive in the `nginx.conf`.

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

TBD

Copyright and License
=====================

TBD

[Back to TOC](#table-of-contents)

See Also
========
* library [lua-resty-core](https://github.com/openresty/lua-resty-core)
* the ngx_lua module: https://github.com/openresty/lua-nginx-module
* OpenResty: http://openresty.org

[Back to TOC](#table-of-contents)

