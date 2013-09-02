Name
====

lua-resty-core - New FFI-based Lua API for the ngx_lua module

Status
======

This library is still under early development and is still incomplete.

Synopsis
========

    # nginx.conf

    http {
        lua_package_path "/path/to/lua-resty-core/lib/?.lua;;";

        init_by_lua '
            require "resty.core"
        ';

        ...
    }

Description
===========

This pure Lua library reimplements part of the ngx_lua's
[Nginx API for Lua](http://wiki.nginx.org/HttpLuaModule#Nginx_API_for_Lua)
with LuaJIT FFI and installs the new FFI-based Lua API into the ngx.* and ndk.* namespaces
used by the ngx_lua module.

The FFI-based Lua API can work with LuaJIT's JIT compiler. ngx_lua's default API is based on the standard Lua C API, which will never be JIT compiled and the user Lua code is always interpreted (slowly).

Prerequisites
=============

* LuaJIT 2.1 (for now, it is the v2.1 git branch in the official luajit-2.0 git repository: http://luajit.org/download.html )
* The "ffi" git branch in the lua-nginx-module repository on GitHub: https://github.com/chaoslawful/lua-nginx-module/tree/ffi

API Implemented
===============

### resty.core.hash

* [ngx.md5](http://wiki.nginx.org/HttpLuaModule#ngx.md5)
* [ngx.md5_bin](http://wiki.nginx.org/HttpLuaModule#ngx.md5_bin)
* [ngx.sha1_bin](http://wiki.nginx.org/HttpLuaModule#ngx.sha1_bin)

### resty.core.base64

* [ngx.encode_base64](http://wiki.nginx.org/HttpLuaModule#ngx.encode_base64)
* [ngx.decode_base64](http://wiki.nginx.org/HttpLuaModule#ngx.decode_base64)

### resty.core.uri

* [ngx.escape_uri](http://wiki.nginx.org/HttpLuaModule#ngx.escape_uri)
* [ngx.unescape_uri](http://wiki.nginx.org/HttpLuaModule#ngx.unescape_uri)

### resty.core.regex

* [ngx.re.match](http://wiki.nginx.org/HttpLuaModule#ngx.re.match)
* [ngx.re.sub](http://wiki.nginx.org/HttpLuaModule#ngx.re.sub)
* [ngx.re.gsub](http://wiki.nginx.org/HttpLuaModule#ngx.re.gsub)

### resty.core.exit

* [ngx.exit](http://wiki.nginx.org/HttpLuaModule#ngx.exit)

### resty.core.shdict

* [ngx.shared.DICT.get](http://wiki.nginx.org/HttpLuaModule#ngx.shared.DICT.get)
* [ngx.shared.DICT.get_stale](http://wiki.nginx.org/HttpLuaModule#ngx.shared.DICT.get_stale)
* [ngx.shared.DICT.incr](http://wiki.nginx.org/HttpLuaModule#ngx.shared.DICT.incr)

### resty.core.var

* [ngx.var.VARIABLE](http://wiki.nginx.org/HttpLuaModule#ngx.var.VARIABLE)  (read-only)

Caveat
======

If the user Lua code is not JIT compiled, then use of this library may
lead to performance drop in interpreted mode. You will only observe
speedup when you get a good part of your user Lua code JIT compiled.

Author
======

Yichun "agentzh" Zhang (章亦春) <agentzh@gmail.com>, CloudFlare Inc.

Copyright and License
=====================

This module is licensed under the BSD license.

Copyright (C) 2013, by Yichun "agentzh" Zhang, CloudFlare Inc.

All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

See Also
========
* the ngx_lua module: http://wiki.nginx.org/HttpLuaModule
* LuaJIT FFI: http://luajit.org/ext_ffi.html

