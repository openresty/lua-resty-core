Name
====

ngx.semaphore for OpenResty/ngx_lua.

Table of Contents
=================

* [Name](#name)
* [Synopsis](#synopsis)
* [Description](#description)
* [Methods](#methods)
    * [new](#new)
    * [wait](#wait)
    * [post](#post)
    * [count](#count)
* [Community](#community)
    * [English Mailing List](#english-mailing-list)
    * [Chinese Mailing List](#chinese-mailing-list)
* [Bugs and Patches](#bugs-and-patches)
* [Author](#author)
* [Copyright and License](#copyright-and-license)
* [See Also](#see-also)

Synopsis
========

```nginx
# demonstrate the usage of the ngx.semaphore
http {
    server {
        location = /example {
            content_by_lua_block {
                local res1, res2 = ngx.location.capture_multi{
                    { "/sem_wait"},
                    { "/sem_post"},
                }
                ngx.say(res1.status)
                ngx.say(res1.body)
                ngx.say(res2.status)
                ngx.say(res2.body)
            }
        }

        location /sem_wait {
            content_by_lua_block {
                local semaphore = require "ngx.semaphore"
                local g = require "mydata" -- please check https://github.com/openresty/lua-nginx-module#data-sharing-within-an-nginx-worker

                if not g.example then
                    local sem, err = semaphore.new(0)
                    if not sem then
                        ngx.say(err)
                        return
                    end
                    g.example = sem
                end
                local sem = g.example
                local ok, err = sem:wait(1)
                if ok then
                    ngx.print("wait")
                end
            }
        }

        location /sem_post {
            content_by_lua_block {
                local semaphore = require "ngx.semaphore"
                local g = require "mydata" -- please check https://github.com/openresty/lua-nginx-module#data-sharing-within-an-nginx-worker

                if not g.example then
                    local sem, err = semaphore.new(0)
                    if not sem then
                        ngx.say(err)
                        ngx.exit(500)
                    end
                    g.example = sem
                end
                local sem = g.example
                ngx.sleep(0.001)
                collectgarbage("collect")
                local ok, err = sem:post()
                if ok then
                    ngx.print("post")
                    ngx.exit(200)
                else
                    ngx.exit(500)
                end
            }
        }
    }
}
```

Description
===========

This module provides APIs to help the OpenResty/ngx_lua user programmers use the semaphore in the same worker.

Methods
=======

[Back to TOC](#table-of-contents)

new
---
**syntax:** *sem, err = ngx.semaphore.new(n)*

**context:** *init_worker_by_lua*, set_by_lua*, rewrite_by_lua*, access_by_lua*, content_by_lua*, header_filter_by_lua*, body_filter_by_lua, log_by_lua*, ngx.timer.**

Creates a semaphore that has n resource. LuaJIT's FFI is needed by this api.

```lua
    local semaphore = require "ngx.semaphore"
    local print = ngx.print
    local sem, err = semaphore.new(0)
    if not sem then
        print("create semaphore failed: "..err)
    end
```

[Back to TOC](#table-of-contents)

wait
------------
**syntax:** *ok, err = sem:wait(timeout?)*

**context:** *rewrite_by_lua*, access_by_lua*, content_by_lua*, ngx.timer.**

The variable `sem` is created by [ngx.semaphore.new](#ngxsemaphorenew). If there have resources then it returns `true` immediately, else the light thread or main thread will yields the executation. then it will be waked up when some one else call the post method[#ngx.semaphore.post|ngx.semaphore.post]] or timeout event occur. The timeout default is 0, which means it will returns `nil`, `busy` if there is no resource to use. LuaJIT's FFI is needed by this api.

```lua
 local semaphore = require "ngx.semaphore"
 local shared =  require "mydata" -- please check https://github.com/openresty/lua-nginx-module#data-sharing-within-an-nginx-worker
 local print = ngx.print
 if not shared.test then
     local sem, err = semaphore.new(0)
     if not sem then
         print("create semaphore failed: "..err)
         ngx.exit(500)
     end
     shared.test = sem
 end
 local sem = shared.test
 local ok, err = sem:wait(10)
 if not ok then
     ngx.print(err)
 end
```

[Back to TOC](#table-of-contents)

post
--------
**syntax:** *ok, err = sem:post(n?)*

**context:** *init_worker_by_lua*, set_by_lua*, rewrite_by_lua*, access_by_lua*, content_by_lua*, header_filter_by_lua*, body_filter_by_lua, log_by_lua*, ngx.timer.**

The param sem is created by [ngx.semaphore.new](#ngxsemaphorenew). Release n resource to a semaphore. If one light thread or coroutine is waiting on this semaphore, then it will be waken up. LuaJIT's FFI is needed by this api.

```lua

 local semaphore = require "ngx.semaphore"
 local shared =  require "mydata" -- please check https://github.com/openresty/lua-nginx-module#data-sharing-within-an-nginx-worker
 local print = ngx.print
 if not shared.test then
     local sem, err = semaphore.new(0)
     if not sem then
         print("create semaphore failed: "..err)
         ngx.exit(500)
     end
     shared.test = sem
 end
 local sem = shared.test
 local ok, err = sem:post()
 if not ok then
     ngx.print(err)
 end
```

[Back to TOC](#table-of-contents)

count
--------
**syntax:** `count = sem:count()`
**context:** *init_worker_by_lua*, set_by_lua*, rewrite_by_lua*, access_by_lua*, content_by_lua*, header_filter_by_lua*, body_filter_by_lua, log_by_lua*, ngx.timer.**

Return the count of the semaphore. LuaJIT's FFI is needed by this api.

```lua
 local semaphore = require "ngx.semaphore"
 local sem = ngx.semaphore.new(2)
 local count = sem:count()  -- count == 2
```

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

Yichun "agentzh" Zhang (章亦春) <agentzh@gmail.com>, CloudFlare Inc.

[Back to TOC](#table-of-contents)

Copyright and License
=====================

This module is licensed under the BSD license.

Copyright (C) 2015, by Yichun "agentzh" Zhang, CloudFlare Inc.

All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

[Back to TOC](#table-of-contents)

See Also
========
* library [lua-resty-core](https://github.com/openresty/lua-resty-core)
* the ngx_lua module: https://github.com/openresty/lua-nginx-module
* OpenResty: http://openresty.org

[Back to TOC](#table-of-contents)

