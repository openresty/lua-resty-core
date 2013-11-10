-- Copyright (C) 2013 Yichun Zhang (agentzh)


local base = require "resty.core.base"


local new_tab = base.new_tab
local getmetatable = getmetatable
local ngx_magic_key_getters = new_tab(0, 4)
local ngx_magic_key_setters = new_tab(0, 4)


local _M = new_tab(0, 3)
_M._VERSION = base.version


function _M.register_ngx_magic_key_getter(key, func)
    ngx_magic_key_getters[key] = func
end


function _M.register_ngx_magic_key_setter(key, func)
    ngx_magic_key_setters[key] = func
end


getmetatable(ngx).__index = function (tb, key)
    return ngx_magic_key_getters[key]()
end


getmetatable(ngx).__newindex = function (tb, key, ctx)
    return ngx_magic_key_setters[key](ctx)
end


return _M
