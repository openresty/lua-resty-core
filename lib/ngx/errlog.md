Name
====

`ngx.errlog` - manage nginx error log data in Lua for OpenResty/ngx_lua.

Table of Contents
=================

* [Name](#name)
* [Status](#status)
* [Synopsis](#synopsis)
    * [Capturing nginx error logs with specified log filtering level](#capturing-nginx-error-logs-with-specified-log-filtering-level)
* [Methods](#methods)
    * [set_filter_level](#set_filter_level)
    * [get_logs](#get_logs)
    * [get_sys_filter_level](#get_sys_filter_level)
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

Capturing nginx error logs with specified log filtering level
-------------------------------------------------------------

```nginx
error logs/error.log info;

http {
    # enable capturing error logs
    lua_capture_error_log 32m;

    init_by_lua_block {
        local errlog = require "ngx.errlog"
        local status, err = errlog.set_filter_level(ngx.WARN)
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
                local errlog = require "ngx.errlog"
                ngx.log(ngx.INFO, "test1")
                ngx.log(ngx.WARN, "test2")
                ngx.log(ngx.ERR, "test3")

                local logs, err = errlog.get_logs(10)
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

set_filter_level
-----------------
**syntax:** *status, err = log_module.set_filter_level(log_level)*

**context:** *init_by_lua&#42;*

Specifies the filter log level, only to capture and buffer the error logs with a log level
no lower than the specified level.

If we don't call this API, all of the error logs will be captured by default.

In case of error, `nil` will be returned as well as a string describing the
error.

This API should always work with directive
[lua_capture_error_log](https://github.com/openresty/lua-nginx-module#lua_capture_error_log).

See [Nginx log level constants](https://github.com/openresty/lua-nginx-module#nginx-log-level-constants) for all nginx log levels.

For example,

```lua
 init_by_lua_block {
     local errlog = require "ngx.errlog"
     errlog.set_filter_level(ngx.WARN)
 }
```

*NOTE:* The debugging logs since when OpenResty or NGINX is not built with `--with-debug`, all the debug level logs are suppressed regardless.

[Back to TOC](#table-of-contents)

get_logs
--------
**syntax:** *res, err = log_module.get_logs(max?, res?)*

**context:** *any*

Fetches the captured nginx error log messages if any in the global data buffer
specified by `ngx_lua`'s
[lua_capture_error_log](https://github.com/openresty/lua-nginx-module#lua_capture_error_log)
directive. Upon return, this Lua function also *removes* those messages from
that global capturing buffer to make room for future new error log data.

In case of error, `nil` will be returned as well as a string describing the
error.

The optional `max` argument is a number that when specified, will prevent
`errlog.get_logs` from adding more than `max` messages to the `res` array.

```lua
for i = 1, 20 do
   ngx.log(ngx.ERR, "test")
end

local errlog = require "ngx.errlog"
local res = errlog.get_logs(10)
-- the number of messages in the `res` table is 10 and the `res` table
-- has 20 elements.
```

The resulting table has the following structure:

```lua
{ level1, msg1, level2, msg2, ... }
```

So to traverse this array, the user can use a loop like this:

```lua
for i = 1, #res, 2 do
    local level = res[i]
    if not level then
        break
    end
    local msg = res[i + 1]
    -- handle the current message with log level in `level` and
    -- log message body in `msg`.
end
```

Specifying `max <= 0` disables this behavior, meaning that the number of
results won't be limited.

The optional 2th argument `res` can be a user-supplied Lua table
to hold the result instead of creating a brand new table. This can avoid
unnecessary table dynamic allocations on hot Lua code paths. It is used like this:

```lua
local errlog = require "ngx.errlog"
local new_tab = require "table.new"

local buffer = new_tab(100 * 2, 0)  -- for 100 messages

local errlog = require "ngx.errlog"
local res, err = errlog.get_logs(0, buffer)
if res then
    -- res is the same table as `buffer`
    for i = 1, #res, 2 do
        local level = res[i]
        if not level then
            break
        end
        local msg = res[i + 1]
        ...
    end
end
```

When provided with a `res` table, `errlog.get_logs` won't clear the table
for performance reasons, but will rather insert a trailing `nil` value
after the last table element.

When the trailing `nil` is not enough for your purpose, you should
clear the table yourself before feeding it into the `errlog.get_logs` function.

[Back to TOC](#table-of-contents)

get_sys_filter_level
--------------------
**syntax:** *log_level = log_module.get_sys_filter_level()*

**context:** *any*

Return the system's default filter level as an integer. Later, the returned
value could be used as an Nginx log level constant. For example:

```lua
local errlog = require "ngx.errlog"
local log_level = error_log.get_sys_filter_level()
-- Now the filter level is always one level higher than system default log level on priority
local status, err = errlog.set_filter_level(log_level - 1)
if not status then
    ngx.log(ngx.ERR, err)
    return
end
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

