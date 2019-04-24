-- Copyright (C) Yichun Zhang (agentzh)

local subsystem = ngx.config.subsystem


require "resty.core.regex"
require "resty.core.shdict"
require "resty.core.time"
require "resty.core.misc"


if subsystem == 'http' then
    require "resty.core.uri"
    require "resty.core.hash"
    require "resty.core.base64"
    require "resty.core.exit"
    require "resty.core.var"
    require "resty.core.ctx"
    require "resty.core.request"
    require "resty.core.response"
    require "resty.core.worker"
    require "resty.core.phase"
    require "resty.core.ndk"
end


local base = require "resty.core.base"


return {
    version = base.version
}
