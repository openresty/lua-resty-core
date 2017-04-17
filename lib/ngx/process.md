Name
====

`ngx.process` - manage the nginx processes for OpenResty/ngx_lua.

Table of Contents
=================

* [Name](#name)
* [Status](#status)
* [Synopsis](#synopsis)
    * [Enable privilege process and get process type](#enable-privilege-process-and-get-process-type)
* [Methods](#methods)
    * [type](#type)
    * [privilege](#privilege)
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

Synopsis
========

Enable privilege process and get process type
-----------------------------------------

```nginx
# http config
init_by_lua_block {
    local process = require "ngx.process"

    -- enable privileged process
    process.privilege(true)

    -- output process type
    ngx.log(ngx.INFO, "process type:", process.type())
}

init_worker_by_lua_block {
    local process = require "ngx.process"
    ngx.log(ngx.INFO, "process type:", process.type())
}

server {
    # ...
    location = /t {
        content_by_lua_block {
            local process = require "ngx.process"
            ngx.say("process type:", process.type())
        }
    }
}

```

The example config above produces an output to `error.log` when
server starts:

```
[lua] init_by_lua:8: process type:0             --> master process
[lua] init_worker_by_lua:3: process type:5      --> privilege process
[lua] init_worker_by_lua:3: process type:3      --> worker process
```

The example location above produces a response:

```
process type:3                                  --> worker process
```

[Back to TOC](#table-of-contents)

Methods
=======

type
---
**syntax:** *type = process_module.type(n?)*

**context:** *init_by_lua&#42;, init_worker_by_lua&#42;, set_by_lua&#42;, rewrite_by_lua&#42;, access_by_lua&#42;, content_by_lua&#42;, header_filter_by_lua&#42;, body_filter_by_lua&#42;, log_by_lua&#42;, ngx.timer.&#42;*

Returns the current process's type, here is all of the types:

```
-- core/base.lua
_M.FFI_PROCESS_SINGLE     = 0
_M.FFI_PROCESS_MASTER     = 1
_M.FFI_PROCESS_SIGNALLER  = 2
_M.FFI_PROCESS_WORKER     = 3
_M.FFI_PROCESS_HELPER     = 4
_M.FFI_PROCESS_PRIVILEGE  = 5
```

For example,

```lua
 local process = require "ngx.process"
 ngx.say("process type:", process.type())
```

[Back to TOC](#table-of-contents)

privilege
---
**syntax:** *status = process_module.privilege(enable)*

**context:** *init_by_lua&#42;*

Enable/disable the privileged process in Nginx.

Here is an example:

```nginx
# http config
init_by_lua_block {
    local process = require "ngx.process"

    -- enable privileged process
    process.privilege(true)
}
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

Yichun Zhang &lt;agentzh@gmail.com&gt; (agentzh), OpenResty Inc.

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
* library [lua-resty-core](https://github.com/openresty/lua-resty-core)
* the ngx_lua module: https://github.com/openresty/lua-nginx-module
* OpenResty: http://openresty.org

[Back to TOC](#table-of-contents)

