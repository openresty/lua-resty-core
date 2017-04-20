Name
====

`ngx.log` - manage the nginx error log for OpenResty/ngx_lua.

Table of Contents
=================

* [Name](#name)
* [Status](#status)
* [Synopsis](#synopsis)
    * [Intercept nginx error logs with specified log level](#intercept-nginx-error-logs-with-specified-log-level)
* [Methods](#methods)
    * [set_errlog_filter](#set_errlog_filter)
    * [get_errlog](#get_errlog)
* [Community](#community)
    * [English Mailing List](#english-mailing-list)
    * [Chinese Mailing List](#chinese-mailing-list)
* [Bugs and Patches](#bugs-and-patches)
* [Author](#author)
* [Copyright and License](#copyright-and-license)
* [See Also](#see-also)

Status
======

This Lua module is currently considered experimental.
The API is still in flux and may change in the future without notice.

Synopsis
========

Intercept nginx error logs with specified log level
-----------------------------------------

```nginx
error logs/error.log info;

http {
    # enable intercept error log
    lua_intercept_error_log 32m;

    init_by_lua_block {
        local ngx_log = require "ngx.log"
        local status, err = ngx_log.set_errlog_filter(ngx.WARN)
        if not status then
            ngx.log(ngx.ERR, err)
            return
        end
        ngx.log(ngx.WARN, "set error filter level: WARN")
    }

    server {
        # ...
        location = /t {
            content_by_lua_block {
                local ngx_log = require "ngx.log"
                ngx.log(ngx.INFO, "test1")
                ngx.log(ngx.WARN, "test2")
                ngx.log(ngx.ERR, "test3")

                local logs, err = ngx_log.get_errlog()
                if not logs then
                    ngx.say("FAILED ", err)
                    return
                end

                for _, log in ipairs(logs) do
                    ngx.say("level: ", log[1], " data: ", log[2])
                end
            }
        }
    }
}

```

The example location above produces a response like this:

```
level: 5 data: 2017/04/19 22:20:03 [warn] 63176#0:
    [lua] init_by_lua:7: set error filter level: WARN
level: 5 data: 2017/04/19 22:20:05 [warn] 63176#0: *1
    [lua] content_by_lua(nginx.conf:59):4: test2
level: 4 data: 2017/04/19 22:20:05 [error] 63176#0: *1
    [lua] content_by_lua(nginx.conf:59):5: test3
```

[Back to TOC](#table-of-contents)

Methods
=======

set_errlog_filter
---
**syntax:** *status, err = log_module.set_errlog_filter(log_level)*

**context:** *init_by_lua&#42;*

Specify the filter log level, only to intercept the error log we need.
If we don't call this API, all of the error logs will be intercepted by default.

In case of error, `nil` will be returned as well as a string describing the
error.

This API should always work with directive [lua_intercept_error_log](https://github.com/openresty/lua-nginx-module#lua_intercept_error_log).

See [Nginx log level constants](https://github.com/openresty/lua-nginx-module#nginx-log-level-constants) for all nginx log levels.

For example,

```lua
 init_by_lua_block {
     local ngx_log = require "ngx.log"
     ngx_log.set_errlog_filter(ngx.WARN)
 }
```

[Back to TOC](#table-of-contents)

get_errlog
---
**syntax:** *res, err = log_module.get_errlog(max, res?)*

**context:** *init_by_lua&#42;, init_worker_by_lua&#42;, set_by_lua&#42;, rewrite_by_lua&#42;, access_by_lua&#42;, content_by_lua&#42;, header_filter_by_lua&#42;, body_filter_by_lua&#42;, log_by_lua&#42;, ngx.timer.&#42;*

Return the intercepted nginx error logs if successful.

In case of error, `nil` will be returned as well as a string describing the
error.

The optional `max` argument is a number that when specified, will prevent
`ngx_log.get_errlog` from adding more than `max` logs to the `res` array.

```lua
 for i = 1, 20 do
    ngx.log(ngx.ERR, "test")
 end

 local ngx_log = require "ngx.log"
 local res = ngx_log.get_errlog(10)
 -- the number of `logs` is 10
```

Specifying `max <= 0` disables this behavior, meaning that the number of
results won't be limited.

The optional 2th argument `res` can be a table that `ngx_log.get_errlog` will
re-use to hold the results instead of creating a new one, which can improve
performance in hot code paths. It is used like so:

```lua
local ngx_log = require "ngx.log"

local my_table = {"hello world"}

local ngx_log = require "ngx.log"
local res = ngx_log.get_errlog(0, my_table)
-- res/my_table is same
```

When provided with a `res` table, `ngx_log.get_errlog` won't clear the table
for performance reasons, but will rather insert a trailing `nil` value
when the `get_errlog` is completed.

When the trailing `nil` is not enough for your purpose, you should
clear the table yourself before feeding it into the `ngx_log.get_errlog` function.

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

Yuansheng Wang &lt;membphis@gmail.com&gt; (membphis), OpenResty Inc.

[Back to TOC](#table-of-contents)

Copyright and License
=====================

This module is licensed under the BSD license.

Copyright (C) 2017, by Yichun "agentzh" Zhang, OpenResty Inc.

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

