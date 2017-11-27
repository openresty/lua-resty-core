-- Copyright (C) Yichun Zhang (agentzh)

local subsystem = ngx.config.subsystem


if subsystem == 'http' then
    require "resty.core.uri"
    require "resty.core.hash"
    require "resty.core.base64"
    require "resty.core.regex"
    require "resty.core.exit"
    require "resty.core.shdict"
    require "resty.core.var"
    require "resty.core.ctx"
    require "resty.core.misc"
    require "resty.core.request"
    require "resty.core.response"
    require "resty.core.time"
    require "resty.core.worker"

    local ngx_re = require "ngx.re"
    ngx.re.split = ngx_re.split
    ngx.re.opt = ngx_re.opt
end


local base = require "resty.core.base"


return {
    version = base.version
}
