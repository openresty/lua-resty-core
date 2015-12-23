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
    * [post](#post)
    * [wait](#wait)
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
                local semaphore = require "ngx.semaphore"
                local sem = semaphore.new()

                local function sem_wait()
                    ngx.say("enter waiting")

                    local ok, err = sem:wait(1)
                    if not ok then
                        ngx.say("err: ", err)
                    else
                        ngx.say("wait success")
                    end
                end

                local co = ngx.thread.spawn(sem_wait)

                ngx.say("back in main thread")

                sem:post()

                ngx.say("still in main thread")

                ngx.sleep(0.01)

                ngx.say("main thread end")
            }
        }
    }
}
```

Description
===========

This module provides semaphore APIs in the OpenResty/ngx_lua.
This APIs works only in the same nginx worker and LuaJIT/FFI is required.

Methods
=======

[Back to TOC](#table-of-contents)

new
---
**syntax:** *sem, err = ngx.semaphore.new(n?)*

**context:** *init_worker_by_lua*, set_by_lua*, rewrite_by_lua*, access_by_lua*, content_by_lua*, header_filter_by_lua*, body_filter_by_lua, log_by_lua*, ngx.timer.**

Creates and returns a semaphore instance that has `n` (default `0`) resources.

```lua
 local semaphore = require "ngx.semaphore"
 local sem, err = semaphore.new(1)
 if not sem then
     ngx.say("create semaphore failed: ", err)
 end
```

[Back to TOC](#table-of-contents)

post
--------
**syntax:** *sem:post(n?)*

**context:** *init_worker_by_lua*, set_by_lua*, rewrite_by_lua*, access_by_lua*, content_by_lua*, header_filter_by_lua*, body_filter_by_lua, log_by_lua*, ngx.timer.**

Release `n` resources to the semaphore instance.
This will not yields the current executation.
At most `n` uthreads will be waked up in the next `nginx event cycle`.

```lua
 local semaphore = require "ngx.semaphore"
 local sem = semaphore.new()

 -- typically, we get the sem from upvalue or globally share data
 -- https://github.com/openresty/lua-nginx-module#data-sharing-within-an-nginx-worker

 sem:post()
```

[Back to TOC](#table-of-contents)

wait
------------
**syntax:** *ok, err = sem:wait(timeout?)*

**context:** *rewrite_by_lua*, access_by_lua*, content_by_lua*, ngx.timer.**

Request a resource from the semaphore instance.
It returns `true` immediately when there have resources and no one have already waiting on the semaphore instance.
Otherwise the current thread will into the waiting queue and yields the current executation, it will be waked and returned `true` until there have resources(some one call the post method [ngx.seamphore.post](#post)) and not one is waiting before it or return `nil`, `timeout` when timeout event occurred.

The param `timeout` default is 0. And it will returns `nil`, `busy` when there is no resources or there have some one already waiting on the semaphore instance.

```lua
 local semaphore = require "ngx.semaphore"
 local sem = semaphore.new()

 local function sem_wait(id)
     ngx.say("enter waiting, id: ", id)

     local ok, err = sem:wait(1)
     if not ok then
         ngx.say("err: ", err)
     else
         ngx.say("wait success, id: ", id)
     end
 end

 local co1 = ngx.thread.spawn(sem_wait, 1)
 local co2 = ngx.thread.spawn(sem_wait, 2)

 ngx.say("back in main thread")

 sem:post(2)

 ngx.say("still in main thread")

 local ok, err = sem:wait(0.01)
 if ok then
     ngx.say("wait success in main thread")
 else
     ngx.say("wait failed in main thread: ", err)
 end

 ngx.sleep(0.01)

 ngx.say("main thread end")
```

[Back to TOC](#table-of-contents)

count
--------
**syntax:** `count = sem:count()`
**context:** *init_worker_by_lua*, set_by_lua*, rewrite_by_lua*, access_by_lua*, content_by_lua*, header_filter_by_lua*, body_filter_by_lua, log_by_lua*, ngx.timer.**

Return the number of resources in the semaphore instance. It means the number of uthreads that is waiting on the semaphore instance when the number is negative.

```lua
 local semaphore = require "ngx.semaphore"
 local sem = ngx.semaphore.new(0)

 ngx.say("count: ", sem:count())  -- count: 0

 local function sem_wait(id)
     local ok, err = sem:wait(1)
     if not ok then
         ngx.say("err: ", err)
     else
         ngx.say("wait success")
     end
 end

 local co1 = ngx.thread.spawn(sem_wait)
 local co2 = ngx.thread.spawn(sem_wait)

 ngx.say("count: ", sem:count())  -- count: -2

 sem:post(1)

 ngx.say("count: ", sem:count())  -- count: -1

 sem:post(2)

 ngx.say("count: ", sem:count())  -- count: 1
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

